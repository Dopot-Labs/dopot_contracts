// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
interface IProjectFactory {
    function emitProjectRewardTierAdded(string calldata _ipfshash) external;
    function emitProjectInvested(address investor) external;
    function emitProjectRefunded(address investor) external;
    function sendNotif(string memory _title, string memory _body, address _recipient, uint256 _payloadType) external;
}

interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, uint256 amount, bytes calldata rewardTier) external returns(uint256);
    function burn(address account, uint256 id, uint256 value) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function whitelistProject(address project) external;
}

contract Project is Initializable, AccessControlEnumerable, ReentrancyGuard {
    IDopotReward dopotRewardContract;
    IERC20 fundingTokenContract;
    using SafeERC20 for IERC20;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    bytes32 public creatorPublicEncryptionKey;
    uint256 public fundRaisingDeadline;
    address addrProjectFactory;
    Utils.AddrParams public addrParams;
    Utils.ProjectParams public projectParams;
    Utils.RewardTier[] public rewardTiers;
    bool public paused;

    function getTiersLength() external view returns (uint256) {
        return rewardTiers.length;
    }

    function togglePause() external onlyRole(REVIEWER_ROLE) {
        paused = !paused;
    }
    
    // rewardTierIndex -> totInvested
    event ChangedState(Utils.State newState, uint256 tierIndex);

    function isState(Utils.State _state, uint256 tierIndex) internal view {
        require(rewardTiers[tierIndex].projectTierState == _state, "Incorrect State");
    }
    function isInvestor() internal view {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender), "Creator or reviewer");
    }

    function initialize(Utils.AddrParams calldata _addrParams, address _creator, address _reviewer, uint256 _fundRaisingDeadline, Utils.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        fundingTokenContract = IERC20(_addrParams.fundingTokenAddress);
        addrProjectFactory = msg.sender;
        addrParams = _addrParams;
        fundRaisingDeadline = _fundRaisingDeadline;
        projectParams = _projectParams;
        _setupRole(DEFAULT_ADMIN_ROLE, _reviewer);
        _setupRole(REVIEWER_ROLE, _reviewer);
        _setupRole(CREATOR_ROLE, _creator);
    }

    function isIpfsHashUnique(string memory ipfsHash) public view returns (bool) {
        for (uint256 i = 0; i < rewardTiers.length; i++) {
            if (keccak256(abi.encodePacked(rewardTiers[i].ipfshash)) == keccak256(abi.encodePacked(ipfsHash))) {
                return false;
            }
        }
        return true;
    }

    function addRewardTier(string memory _ipfshash, uint256 _investment, uint256 _supply) external onlyRole(CREATOR_ROLE) nonReentrant {
        require(!paused && rewardTiers.length < projectParams.rewardsLimit && isIpfsHashUnique(_ipfshash));
        rewardTiers.push(Utils.RewardTier(_ipfshash, 0, _investment, _supply, address(0), Utils.State.PendingApproval));
        IProjectFactory(addrProjectFactory).emitProjectRewardTierAdded(_ipfshash);
    }

    function fundingExpired(uint256 tierIndex) internal returns (bool){
        uint256 deadline = fundRaisingDeadline;
        if(Utils.isDeadlineRange(deadline)) return false;
        if((block.timestamp > deadline) && rewardTiers[tierIndex].projectTierState == Utils.State.Ongoing) {
            rewardTiers[tierIndex].projectTierState = Utils.State.Expired;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Tier deadline reached", getRole(CREATOR_ROLE), 3);
            emit ChangedState(Utils.State.Expired, tierIndex);
        }
        return (block.timestamp > deadline);
    }
    // Creator pays to postpone deadline
    // tierIndexOngoing: index of an ongoing tier
    function postponeDeadline(uint256 tierIndexOngoing) external onlyRole(CREATOR_ROLE) nonReentrant{
        isState(Utils.State.Ongoing, tierIndexOngoing);
        address _dptTokenAddress = addrParams.dptTokenAddress;
        uint256 fundingTokenBalance = fundingTokenContract.balanceOf(address(this));
        require(!paused && fundingTokenBalance >= (projectParams.goal  *  projectParams.postponeThreshold / 1e18));
        IERC20(_dptTokenAddress).safeTransferFrom(msg.sender, getRole(REVIEWER_ROLE), Utils.dptOracleQuote(projectParams.goal - fundingTokenBalance, projectParams.postponeFee, _dptTokenAddress, addrParams.dptUniPoolAddress, addrParams.fundingTokenAddress));
        fundRaisingDeadline += projectParams.postponeAmount;
    }

    // User invests in specified reward tier
    function invest (uint256 tierIndex, uint256 amount) external {
        isInvestor();
        isState(Utils.State.Ongoing, tierIndex);
        require(!paused && !fundingExpired(tierIndex), "Paused or expired");
        Utils.RewardTier memory r = rewardTiers[tierIndex];
		fundingTokenContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment * amount);
        r.tokenId = dopotRewardContract.mintToken(msg.sender, r.ipfshash, amount, Utils.rewardTierToBytes(r));
        IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Someone invested in your project", getRole(CREATOR_ROLE), 3);
        IProjectFactory(addrProjectFactory).emitProjectInvested(msg.sender);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw(bool discountDPT) external onlyRole(CREATOR_ROLE) nonReentrant{
        address _fundToken = addrParams.fundingTokenAddress;
        IERC20 _fundingTokenContract = fundingTokenContract;
        uint256 balance = _fundingTokenContract.balanceOf(address(this));
        require(!paused && balance >= projectParams.goal);
        uint256 feeAmount = balance *  projectParams.projectWithdrawalFee  / 1e18;
        uint256 insuranceAmount = balance * projectParams.insurance / 1e18;
        IERC20(discountDPT ? addrParams.dptTokenAddress : _fundToken).safeTransferFrom(discountDPT ? msg.sender : address(this), getRole(REVIEWER_ROLE), discountDPT ? Utils.dptOracleQuote(balance, projectParams.projectDiscountedWithdrawalFee, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken) : feeAmount);
        _fundingTokenContract.safeTransfer(msg.sender, discountDPT? balance - insuranceAmount : balance - insuranceAmount - feeAmount);
        _fundingTokenContract.safeTransfer(addrProjectFactory, insuranceAmount);
        for(uint256 i = 0; i < rewardTiers.length; i++){
            changeState(Utils.State.Successful, i);
        }
    }

    // Investor requests refund for rewards of specified tier
    function refund(uint256 tierIndex, uint256 amount) external {
        isInvestor();
        require(!paused && fundingExpired(tierIndex) || rewardTiers[tierIndex].projectTierState == Utils.State.Ongoing || rewardTiers[tierIndex].projectTierState == Utils.State.Cancelled);
        dopotRewardContract.burn(msg.sender, rewardTiers[tierIndex].tokenId, amount);
        IERC20(addrParams.fundingTokenAddress).transfer(msg.sender, rewardTiers[tierIndex].investment * amount);
        IProjectFactory(addrProjectFactory).emitProjectRefunded(msg.sender);
    }

    function setPublicEncryptionKey(bytes32 _creatorPublicEncryptionKey) external onlyRole(CREATOR_ROLE) {
        creatorPublicEncryptionKey = _creatorPublicEncryptionKey;
    }

    function changeState(Utils.State newState, uint256 tierIndex) public onlyRole(REVIEWER_ROLE) {
        rewardTiers[tierIndex].projectTierState = newState;
        if((newState == Utils.State.Ongoing) && Utils.isDeadlineRange(fundRaisingDeadline)) {
            fundRaisingDeadline += block.timestamp;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Now ongoing", getRole(CREATOR_ROLE), 3);
        }
        emit ChangedState(newState, tierIndex);
    }

    function getRole(bytes32 _role) view internal returns(address){
        return getRoleMember(_role, 0);
    }
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

