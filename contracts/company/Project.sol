// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, uint256 amount, bytes calldata rewardTier) external returns(uint256); 
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function burn(address account, uint256 id, uint256 value) external;
    function whitelistProject(address project) external;
}

contract Project is Initializable, AccessControl, ReentrancyGuard, IPFS{
    IDopotReward dopotRewardContract;
    //bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");: 
    //Needed only to interact with untrusted token contract
    using SafeERC20 for IERC20;
    uint constant public projectWithdrawalFee = 3/100 * 1e18;
    uint constant public projectDiscountedWithdrawalFee = 2/100 * 1e18;
    uint constant public projectMediaLimit = 4;
    uint constant public rewardsLimit = 4;

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    address payable public reviewer;
    uint public fundRaisingDeadline;
    //address private dptTokenContract;
    address private fundingTokenContract;

    enum State {
        PendingApproval,
        Rejected,
        Ongoing,
        Successful,
        Expired,
        Cancelled
    }
    State public projectState;

    IPFS.RewardTier[] public rewardTiers;
    string[] public projectMedia;
    string public projectSurvey;

    // rewardTierIndex -> totInvested

    modifier isState(State _state){
        require(projectState == _state, "Project state error");
        _;
    }
    modifier isProjectCancellable(){
        require(projectState == State.PendingApproval || projectState == State.Ongoing);
        _;
    }
    modifier isInvestor() {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
        _;
    }

    event Invested(address indexed payee, uint256 indexed tierIndex, uint256 amount);
    event Refunded(address indexed payee, uint256 indexed tierIndex, uint256 amount);
    event ChangedState(State newState);

    function initialize(address payable _creator, address payable _reviewer, uint _fundRaisingDeadline,
    string[] calldata _projectMedia, IPFS.RewardTier[] calldata _rewardTiers, string calldata _projectSurvey, address _fundingTokenContract, address _dopotRewardAddress/*, address _dptTokenContract*/) external initializer {
        dopotRewardContract = IDopotReward(_dopotRewardAddress);
        fundRaisingDeadline = _fundRaisingDeadline;
        projectSurvey = _projectSurvey;
        for (uint i=0; i < _projectMedia.length; i += 1) {
            if(i < projectMediaLimit)
                projectMedia.push(_projectMedia[i]);
        }
        for (uint i=0; i < _rewardTiers.length; i += 1) {
            if(i < rewardsLimit){
                uint tokenid =  dopotRewardContract.mintToken(address(this), _rewardTiers[i].ipfshash, _rewardTiers[i].supply, rewardTierToBytes(_rewardTiers[i]));
                rewardTiers.push(_rewardTiers[i]);
                rewardTiers[i].tokenId = tokenid;                
            }
        }
        projectState = State.PendingApproval;
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
        _setupRole(CREATOR_ROLE, _creator);
        _setupRole(REVIEWER_ROLE, _reviewer);
        reviewer = _reviewer;
    }

    function fundingGoalReached(uint tierIndex) public view returns (bool) {
        return dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) == 0;
    }

    function fundingExpired() private returns (bool){
        bool isExpired = (block.timestamp > fundRaisingDeadline);
        
        if(isExpired && projectState == State.Ongoing) {
            _changeState(State.Expired);
            emit ChangedState(State.Expired);
        }
        return isExpired;
    }
    
    // User invests in specified reward tier 
    function invest (uint256 tierIndex, uint256 amount) external isInvestor isState(State.Ongoing) nonReentrant {
        require(!fundingExpired());
        require(dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) >= amount);
        uint investAmount = rewardTiers[tierIndex].investment * amount;
        uint256 allowance = IERC20(fundingTokenContract).allowance(msg.sender, address(this));
        require(allowance >= investAmount, "Insufficient token allowance");

		IERC20(fundingTokenContract).safeTransferFrom(msg.sender, address(this), investAmount);
        dopotRewardContract.safeTransferFrom(address(this), msg.sender, rewardTiers[tierIndex].tokenId, amount, "");

        emit Invested(msg.sender, tierIndex, amount);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw(uint tierIndex) external onlyRole(CREATOR_ROLE) nonReentrant {
        if(!fundingExpired())
            require(fundingGoalReached(tierIndex), "Funding goal not reached");
        else require(fundingExpired(), "Funding not expired");
        uint amount = address(this).balance; // <<<<< NO!!!! only specified tier's money
        uint feeAmount = amount * /* (IERC20(dptTokenContract).balanceOf(msg.sender, dptTokenContract) > 0 ? projectDiscountedWithdrawalFee : */ projectWithdrawalFee /*)*/ / 1e18;

        IERC20(fundingTokenContract).safeTransfer(reviewer, feeAmount);
        IERC20(fundingTokenContract).safeTransfer(msg.sender, amount - feeAmount);
        _changeState(State.Successful);
        emit ChangedState(State.Successful); // <<<<< NO!!!! only specified tier
    }

    // Creator or Reviewer cancels pending or ongoing project permitting eventual refunds to investors
    function cancel() external isProjectCancellable {
        require(hasRole(REVIEWER_ROLE, msg.sender) || hasRole(CREATOR_ROLE, msg.sender));

        /*Burn if rewards of tier are all owned by this
        for (uint i=0; i < rewardTiers.length; i += 1) {
            rewardTiers[i].tokenId;
            if(dopotRewardContract.balanceOf(address(this), rewardTiers[i].tokenId) == rewardTiers[i].supply)
                dopotRewardContract.burn(address(this), rewardTiers[i].tokenId, 0);
        }*/
        projectState = State.Cancelled;
    }

    // Investor requests refund for rewards of specified tier
    function refundRewardTier(uint256 tierIndex, uint256 amount) external isInvestor nonReentrant {
        require(fundingExpired() || projectState == State.Cancelled, "Funding not expired or cancelled");
        if(projectState != State.Cancelled) require(!fundingGoalReached(tierIndex), "Refund not available because funding goal reached");
        require(dopotRewardContract.balanceOf(msg.sender, rewardTiers[tierIndex].tokenId) == amount);

        dopotRewardContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].tokenId, amount, "");
        IERC20(fundingTokenContract).safeTransfer(msg.sender, rewardTiers[tierIndex].investment * amount);

        emit Refunded(msg.sender, tierIndex, amount);
    }

    function changeState(State newState) external onlyRole(REVIEWER_ROLE) {
        projectState = newState;
        emit ChangedState(newState);
    }

    function _changeState(State newState) internal {
        projectState = newState;
        emit ChangedState(newState);
    }

    function changeReviewer(address newReviewer) external onlyRole(REVIEWER_ROLE) {
        reviewer = payable(newReviewer);
        _revokeRole(REVIEWER_ROLE, msg.sender);
        _grantRole(REVIEWER_ROLE, newReviewer);
    }
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}