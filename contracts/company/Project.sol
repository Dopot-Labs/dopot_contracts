// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
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

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    address payable public reviewer;
    uint public fundRaisingDeadline;
    IPFS.AddrParams addrParams;
    IPFS.ProjectParams projectParams;
    IPFS.RewardTier[] public rewardTiers;
    string public projectMedia;
    string public projectSurvey;
    bytes32 public publicEncryptionKey;
    uint public totalGoal;

    // rewardTierIndex -> totInvested
    error StateError();
    error DptRewardBalanceError();
    error DptBalanceError();
    function isState(State _state, uint tierIndex) private view {
        if(rewardTiers[tierIndex].projectTierState != _state) revert StateError();
    }
    function isInvestor() private view {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
    }

    function dptOracleQuote(uint amount, uint fee) private view returns (uint quoteAmount){
        if(IERC20(addrParams.dptTokenAddress).balanceOf(msg.sender) == 0) revert DptBalanceError();
        //secondsAgo: 60 * 60 * 24 (24h)
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 60 * 60 * 24;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives,) = IUniswapV3Pool(addrParams.dptUniPoolAddress).observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = int24(tickCumulativesDelta / int56(uint56(60 * 60 * 24)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(60 * 60 * 24)) != 0)) tick--;
        quoteAmount = OracleLibrary.getQuoteAtTick(tick, uint128(amount *  fee  / 1e18), addrParams.fundingTokenAddress, addrParams.dptTokenAddress);
    }

    event Invested(address indexed payee, uint256 indexed tierIndex, uint256 amount);
    event Refunded(address indexed payee, uint256 indexed tierIndex, uint256 amount);
    event ChangedState(State newState, uint tierIndex);
    event PostponedDeadline();

    function initialize(IPFS.AddrParams memory _addrParams, uint _fundRaisingDeadline, string memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory _projectSurvey, IPFS.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        addrParams = _addrParams;
        projectParams = _projectParams;
        for (uint i = 0; i < _rewardTiers.length;) {
            if(i < projectParams.rewardsLimit){
                _rewardTiers[i].tokenId = dopotRewardContract.mintToken(address(this), _rewardTiers[i].ipfshash, _rewardTiers[i].supply, IPFS.rewardTierToBytes(_rewardTiers[i]));
                rewardTiers.push(_rewardTiers[i]);
                totalGoal += _rewardTiers[i].investment * _rewardTiers[i].supply;
            } else break;
            unchecked { i++; }
        }        
        fundRaisingDeadline = _fundRaisingDeadline;
        projectSurvey = _projectSurvey;
        projectMedia = _projectMedia;
        _setupRole(CREATOR_ROLE, _addrParams.creator);
        _setupRole(REVIEWER_ROLE, _addrParams.reviewer);
        reviewer = _addrParams.reviewer;
    }

    function fundingExpired(uint tierIndex) private returns (bool){
        bool isExpired = (block.timestamp > fundRaisingDeadline);
        if(isExpired && rewardTiers[tierIndex].projectTierState == State.Ongoing) {
            rewardTiers[tierIndex].projectTierState = State.Expired;
            emit ChangedState(State.Expired, tierIndex);
        }
        return isExpired;
    }
    
    //tierIndexOngoing: index of an ongoing tier
    function postponeDeadline(uint tierIndexOngoing) external onlyRole(CREATOR_ROLE) nonReentrant{
        isState(State.Ongoing, tierIndexOngoing);
        IERC20(addrParams.dptTokenAddress).safeTransfer(reviewer, dptOracleQuote(totalGoal, projectParams.postponeFee));
        fundRaisingDeadline += projectParams.postponeAmount;
        emit PostponedDeadline();
    }

    // User invests in specified reward tier 
    function invest (uint tierIndex, uint amount) external nonReentrant {
        isInvestor();
        isState(State.Ongoing, tierIndex);
        require(!fundingExpired(tierIndex));
        require(dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) >= amount);

		IERC20(addrParams.fundingTokenAddress).safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment * amount);
        dopotRewardContract.safeTransferFrom(address(this), msg.sender, rewardTiers[tierIndex].tokenId, amount, "");
        emit Invested(msg.sender, tierIndex, amount);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw(uint tierIndex, bool discountDPT) external onlyRole(CREATOR_ROLE) nonReentrant{
        require(rewardTiers[tierIndex].projectTierState == State.Ongoing || rewardTiers[tierIndex].projectTierState == State.Expired);
        if(dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) > 0) revert DptRewardBalanceError();
        
        uint amount = rewardTiers[tierIndex].supply * rewardTiers[tierIndex].investment;
        if(discountDPT){
            IERC20(addrParams.dptTokenAddress).safeTransfer(reviewer, dptOracleQuote(amount, projectParams.projectDiscountedWithdrawalFee));
            IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, amount);
        } else{
            uint feeAmount = amount *  projectParams.projectWithdrawalFee  / 1e18;
            IERC20(addrParams.fundingTokenAddress).safeTransfer(reviewer, feeAmount);
            IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, amount - feeAmount);
        }
        rewardTiers[tierIndex].projectTierState = State.Successful;
        emit ChangedState(State.Successful, tierIndex);
    }
    
    // Creator or Reviewer cancels pending or ongoing tier permitting refunds to investors
    function cancel(uint tierIndex) external nonReentrant {
        require(hasRole(REVIEWER_ROLE, msg.sender) || hasRole(CREATOR_ROLE, msg.sender));
        require(rewardTiers[tierIndex].projectTierState == State.PendingApproval || rewardTiers[tierIndex].projectTierState == State.Ongoing);
        //Burn rewards
        for (uint i=0; i < dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId);) {
            dopotRewardContract.burn(address(this), rewardTiers[i].tokenId, 0);
            unchecked { i++; }
        }
        rewardTiers[tierIndex].projectTierState = State.Cancelled;
        emit ChangedState(State.Cancelled, tierIndex);
    }

    // Investor requests refund for rewards of specified tier
    function refund(uint tierIndex, uint256 amount) external nonReentrant {
        isInvestor();
        if(!fundingExpired(tierIndex) && rewardTiers[tierIndex].projectTierState != State.Cancelled) revert StateError();
        if(rewardTiers[tierIndex].projectTierState != State.Cancelled) if(dopotRewardContract.balanceOf(address(this), rewardTiers[tierIndex].tokenId) == 0) revert DptRewardBalanceError();
        require(dopotRewardContract.balanceOf(msg.sender, rewardTiers[tierIndex].tokenId) >= amount);
        dopotRewardContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].tokenId, amount, "");
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, rewardTiers[tierIndex].investment * amount);
        emit Refunded(msg.sender, tierIndex, amount);
    }

    function setPublicEncryptionKey(bytes32 _publicEncryptionKey) external onlyRole(CREATOR_ROLE) {
        publicEncryptionKey = _publicEncryptionKey;
    }

    function changeState(State newState, uint tierIndex) external onlyRole(REVIEWER_ROLE) {
        rewardTiers[tierIndex].projectTierState = newState;
        emit ChangedState(newState, tierIndex);
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

