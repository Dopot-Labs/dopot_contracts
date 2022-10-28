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
    uint public totalGoal;

    // rewardTierIndex -> totInvested
    error BalanceError();
    event ChangedState(State newState, uint tierIndex);

    function isState(State _state, uint tierIndex) internal view {
        require(rewardTiers[tierIndex].projectTierState == _state);
    }
    function isInvestor() internal view {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
    }

    function initialize(Utils.AddrParams calldata _addrParams, address _creator, address _reviewer, uint _fundRaisingDeadline, string memory _projectMedia, Utils.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        addrParams = _addrParams;
        fundRaisingDeadline = _fundRaisingDeadline;
        projectMedia = _projectMedia;
        projectParams = _projectParams;
        _setupRole(DEFAULT_ADMIN_ROLE, _reviewer);
        _setupRole(REVIEWER_ROLE, _reviewer);
        _setupRole(CREATOR_ROLE, _creator);
    }

    function addRewardTier(string memory _ipfshash, uint _investment, uint _supply) external onlyRole(CREATOR_ROLE){
        require(rewardTiers.length < projectParams.rewardsLimit);
        RewardTier memory temp = RewardTier(_ipfshash, 0, _investment, _supply, address(0), State.PendingApproval);
        temp.tokenId = dopotRewardContract.mintToken(address(this), _ipfshash, _supply, Utils.rewardTierToBytes(temp));
        rewardTiers.push(temp);
        totalGoal += _investment * _supply;
    }

    function fundingExpired(uint tierIndex) internal returns (bool){
        uint deadline = fundRaisingDeadline;
        if(isDeadlineRange(deadline)) return false;
        if((block.timestamp > deadline) && rewardTiers[tierIndex].projectTierState == State.Ongoing) {
            rewardTiers[tierIndex].projectTierState = State.Expired;
            Utils.sendNotif(projectUpdateMsg, "Tier deadline reached", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
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
        //Utils.sendNotif(projectUpdateMsg, "Someone invested in your project", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw(uint tierIndex, bool discountDPT) external onlyRole(CREATOR_ROLE) nonReentrant{
        State _projectTierState = rewardTiers[tierIndex].projectTierState;
        require(fundingExpired(tierIndex) || _projectTierState == State.Ongoing);
        address _fundToken = addrParams.fundingTokenAddress;
        uint tokenId = rewardTiers[tierIndex].tokenId;
        if(dopotRewardContract.balanceOf(address(this), tokenId) != 0) revert BalanceError();
        uint amount = rewardTiers[tierIndex].supply * rewardTiers[tierIndex].investment;
        uint feeAmount = amount *  projectParams.projectWithdrawalFee  / 1e18;
        IERC20(discountDPT ? addrParams.dptTokenAddress : _fundToken).safeTransfer(getRole(REVIEWER_ROLE), discountDPT ? dptOracleQuote(amount, projectParams.projectDiscountedWithdrawalFee, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken) : feeAmount);
        IERC20(_fundToken).safeTransfer(msg.sender, discountDPT? amount : amount - feeAmount);  
        changeState(State.Successful, tierIndex);
    }
    
    // Creator or Reviewer cancels pending or ongoing tier permitting refunds to investors
    function cancel(uint tierIndex) external nonReentrant {
        State _projectTierState = rewardTiers[tierIndex].projectTierState;
        require((hasRole(REVIEWER_ROLE, msg.sender) || hasRole(CREATOR_ROLE, msg.sender)) && (_projectTierState == State.PendingApproval || _projectTierState == State.Ongoing));
        rewardTiers[tierIndex].projectTierState = State.Cancelled;
        totalGoal -= rewardTiers[tierIndex].investment * rewardTiers[tierIndex].supply;
    }

    // Investor requests refund for rewards of specified tier
    function refund(uint tierIndex, uint amount) external nonReentrant {
        isInvestor();
        IDopotReward reward = dopotRewardContract;
        uint _tokenId = rewardTiers[tierIndex].tokenId;
        if(rewardTiers[tierIndex].projectTierState != State.Cancelled){
            require(fundingExpired(tierIndex));
            if(reward.balanceOf(address(this), _tokenId) == 0) revert BalanceError();
        }
        reward.safeTransferFrom(msg.sender, address(this), _tokenId, amount, "");
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, rewardTiers[tierIndex].investment * amount);
    }

    function setPublicEncryptionKey(bytes32 _creatorPublicEncryptionKey) external onlyRole(CREATOR_ROLE) {
        creatorPublicEncryptionKey = _creatorPublicEncryptionKey;
    }

    function changeState(State newState, uint tierIndex) public onlyRole(REVIEWER_ROLE) {
        rewardTiers[tierIndex].projectTierState = newState;
        if((newState == State.Ongoing) && isDeadlineRange(fundRaisingDeadline)) {
            fundRaisingDeadline += block.timestamp;
                Utils.sendNotif(projectUpdateMsg, "Now ongoing", getRole(CREATOR_ROLE), 3, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
        }
        emit ChangedState(newState, tierIndex);
    }
    function isDeadlineRange(uint _deadline) pure internal returns(bool){
        return (_deadline == 45 days || _deadline == 65 days || _deadline == 90 days);
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

