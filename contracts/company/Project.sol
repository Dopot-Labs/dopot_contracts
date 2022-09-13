// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "hardhat/console.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, uint256 amount, bytes calldata rewardTier) external returns(uint256); 
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function whitelistProject(address project) external;
}

contract Project is Initializable, AccessControlEnumerable, ReentrancyGuard, Utils{
    IDopotReward dopotRewardContract;
    using SafeERC20 for IERC20;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    bytes32 public creatorPublicEncryptionKey;
    uint public fundRaisingDeadline;
    Utils.AddrParams addrParams;
    Utils.ProjectParams projectParams;
    Utils.RewardTier[] public rewardTiers;
    string public projectMedia;
    string public projectSurvey;
    uint public totalGoal;

    // rewardTierIndex -> totInvested
    error StateError();
    error BalanceError();
    event Invested(address indexed payee, uint indexed tierIndex, uint256 amount);
    event Refunded(address indexed payee, uint indexed tierIndex, uint256 amount);
    event ChangedState(State newState, uint tierIndex);

    function isState(State _state, uint tierIndex) internal view {
        if(rewardTiers[tierIndex].projectTierState != _state) revert StateError();
    }
    function isInvestor() internal view {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
    }

    function initialize(Utils.AddrParams calldata _addrParams, address _creator, address _reviewer, uint _fundRaisingDeadline, string memory _projectMedia, Utils.RewardTier[] memory _rewardTiers, string memory _projectSurvey, Utils.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        addrParams = _addrParams;
        uint tempGoal;
        for (uint i; i < _rewardTiers.length;) {
            if(i < _projectParams.rewardsLimit){
                _rewardTiers[i].tokenId = dopotRewardContract.mintToken(address(this), _rewardTiers[i].ipfshash, _rewardTiers[i].supply, Utils.rewardTierToBytes(_rewardTiers[i]));
                rewardTiers.push(_rewardTiers[i]);
                tempGoal += _rewardTiers[i].investment * _rewardTiers[i].supply;
            } else break;
            unchecked { ++i; }
        }
        totalGoal += tempGoal;
        fundRaisingDeadline = _fundRaisingDeadline;
        projectSurvey = _projectSurvey;
        projectMedia = _projectMedia;
        projectParams = _projectParams;
        _setupRole(DEFAULT_ADMIN_ROLE, _reviewer);
        _setupRole(REVIEWER_ROLE, _reviewer);
        _setupRole(CREATOR_ROLE, _creator);
    }

    function fundingExpired(uint tierIndex) internal returns (bool){
        uint deadline = fundRaisingDeadline;
        if(isDeadlineRange()) return false;
        if((block.timestamp > deadline) && rewardTiers[tierIndex].projectTierState == State.Ongoing) {
            rewardTiers[tierIndex].projectTierState = State.Expired;
            Utils.sendNotif(projectUpdateMsg, "Reward tier deadline reached but goal not met", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
            emit ChangedState(State.Expired, tierIndex);
        }
        return (block.timestamp > deadline);
    }
    // Creator pays to postpone deadline
    // tierIndexOngoing: index of an ongoing tier
    function postponeDeadline(uint tierIndexOngoing) external onlyRole(CREATOR_ROLE) nonReentrant{
        isState(State.Ongoing, tierIndexOngoing);
        address _fundToken = addrParams.fundingTokenAddress;
        address _dptTokenAddress = addrParams.dptTokenAddress;
        uint fundingTokenBalance = IERC20(_fundToken).balanceOf(address(this));
        if(fundingTokenBalance < (totalGoal  *  projectParams.postponeThreshold / 1e18)) revert BalanceError();
        IERC20(_dptTokenAddress).safeTransferFrom(msg.sender, getRole(REVIEWER_ROLE), dptOracleQuote(totalGoal - fundingTokenBalance, projectParams.postponeFee, _dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken));
        fundRaisingDeadline += projectParams.postponeAmount;
    }

    // User invests in specified reward tier 
    function invest (uint tierIndex, uint amount) external nonReentrant {
        isInvestor();
        isState(State.Ongoing, tierIndex);
        require(!fundingExpired(tierIndex));
        uint _tokenId = rewardTiers[tierIndex].tokenId;
		IERC20(addrParams.fundingTokenAddress).safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment * amount);
        dopotRewardContract.safeTransferFrom(address(this), msg.sender, _tokenId, amount, "");
        Utils.sendNotif(projectUpdateMsg, "Someone invested in your project", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
        emit Invested(msg.sender, tierIndex, amount);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw(uint tierIndex, bool discountDPT) external onlyRole(CREATOR_ROLE) nonReentrant{
        State _projectTierState = rewardTiers[tierIndex].projectTierState;
        require(_projectTierState == State.Ongoing || _projectTierState == State.Expired);
        address _fundToken = addrParams.fundingTokenAddress;
        if(dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) != 0) revert BalanceError();
        uint amount = rewardTiers[tierIndex].supply * rewardTiers[tierIndex].investment;
        uint feeAmount = amount *  projectParams.projectWithdrawalFee  / 1e18;
        IERC20(discountDPT ? addrParams.dptTokenAddress : _fundToken).safeTransfer(getRole(REVIEWER_ROLE), discountDPT ? dptOracleQuote(amount, projectParams.projectDiscountedWithdrawalFee, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken) : feeAmount);
        IERC20(_fundToken).safeTransfer(msg.sender, discountDPT? amount : amount - feeAmount);  
        rewardTiers[tierIndex].projectTierState = State.Successful;
        emit ChangedState(State.Successful, tierIndex);
    }
    
    // Creator or Reviewer cancels pending or ongoing tier permitting refunds to investors
    function cancel(uint tierIndex) external nonReentrant {
        State _projectTierState = rewardTiers[tierIndex].projectTierState;
        require((hasRole(REVIEWER_ROLE, msg.sender) || hasRole(CREATOR_ROLE, msg.sender)) && (_projectTierState == State.PendingApproval || _projectTierState == State.Ongoing));
        rewardTiers[tierIndex].projectTierState = State.Cancelled;
        emit ChangedState(State.Cancelled, tierIndex);
    }

    // Investor requests refund for rewards of specified tier
    function refund(uint tierIndex, uint amount) external nonReentrant {
        isInvestor();
        IDopotReward reward = dopotRewardContract;
        uint _tokenId = rewardTiers[tierIndex].tokenId;
        if(rewardTiers[tierIndex].projectTierState != State.Cancelled){
            if(!fundingExpired(tierIndex)) revert StateError();
            if(reward.balanceOf(address(this), _tokenId) == 0) revert BalanceError();
        }
        reward.safeTransferFrom(msg.sender, address(this), _tokenId, amount, "");
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, rewardTiers[tierIndex].investment * amount);
        emit Refunded(msg.sender, tierIndex, amount);
    }

   

    function setPublicEncryptionKey(bytes32 _creatorPublicEncryptionKey) external onlyRole(CREATOR_ROLE) {
        creatorPublicEncryptionKey = _creatorPublicEncryptionKey;
    }

    function changeState(State newState, uint tierIndex) external onlyRole(REVIEWER_ROLE) {
        rewardTiers[tierIndex].projectTierState = newState;
        if((newState == State.Ongoing) && isDeadlineRange()) {
            fundRaisingDeadline += block.timestamp;
                Utils.sendNotif(projectUpdateMsg, "Your project is now ongoing", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
        }
        emit ChangedState(newState, tierIndex);
    }
    function isDeadlineRange() view internal returns(bool){
        return (fundRaisingDeadline == 45 days || fundRaisingDeadline == 65 days || fundRaisingDeadline == 90 days);
    }

    function getRole(bytes32 _role) view internal returns(address){
        return getRoleMember(_role, 0);
    }

    function onERC1155Received(address, address, uint, uint, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(address, address, uint[] memory, uint[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

