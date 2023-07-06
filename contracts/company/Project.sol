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
    function emitProjectRewardTierAdded(string calldata _hash) external;
    function emitProjectInvested(address investor, uint tokenId) external;
    function emitProjectRefunded(address investor, uint tokenId) external;
    function sendNotif(string memory _title, string memory _body, address _recipient, uint256 _payloadType) external;
    function emitChangedState(Utils.State newState) external;
}

interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, bytes calldata rewardTier) external returns(uint256);
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
    uint256 public fundRaisingDeadline;
    address addrProjectFactory;
    Utils.AddrParams public addrParams;
    Utils.ProjectParams public projectParams;
    Utils.RewardTier[] public rewardTiers;
    bool public paused;
    Utils.State public state;

    function getTiersLength() external view returns (uint256) {
        return rewardTiers.length;
    }

    function togglePause() external onlyRole(REVIEWER_ROLE) {
        paused = !paused;
    }
    
    function isState(Utils.State _state) internal view {
        require(state == _state, "Incorrect State");
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

    function isHashUnique(string memory hash) public view returns (bool) {
        for (uint256 i = 0; i < rewardTiers.length; i++) {
            if (keccak256(abi.encodePacked(rewardTiers[i].hash)) == keccak256(abi.encodePacked(hash))) {
                return false;
            }
        }
        return true;
    }

    function addRewardTier(string memory _hash, uint256 _investment, uint256 _supply) external onlyRole(CREATOR_ROLE) nonReentrant {
        require(!paused && rewardTiers.length < projectParams.rewardsLimit && isHashUnique(_hash));
        rewardTiers.push(Utils.RewardTier(_hash, 0, _investment, _supply, address(0)));
        IProjectFactory(addrProjectFactory).emitProjectRewardTierAdded(_hash);
    }

    function fundingExpired() internal returns (bool){
        uint256 deadline = fundRaisingDeadline;
        if(Utils.isDeadlineRange(deadline)) return false;
        if((block.timestamp > deadline) && state == Utils.State.Ongoing) {
            state = Utils.State.Expired;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Tier deadline reached", getRole(CREATOR_ROLE), 3);
            IProjectFactory(addrProjectFactory).emitChangedState(Utils.State.Expired);
        }
        return (block.timestamp > deadline);
    }
    // Creator pays to postpone deadline
    function postponeDeadline() external onlyRole(CREATOR_ROLE) nonReentrant{
        isState(Utils.State.Ongoing);
        address _dptTokenAddress = addrParams.dptTokenAddress;
        uint256 fundingTokenBalance = fundingTokenContract.balanceOf(address(this));
        require(!paused && fundingTokenBalance >= (projectParams.goal  *  projectParams.postponeThreshold / 1e18));
        IERC20(_dptTokenAddress).safeTransferFrom(msg.sender, getRole(REVIEWER_ROLE), Utils.dptOracleQuote(projectParams.goal - fundingTokenBalance, projectParams.postponeFee, _dptTokenAddress, addrParams.dptUniPoolAddress, addrParams.fundingTokenAddress));
        fundRaisingDeadline += projectParams.postponeAmount;
    }

    // User invests in specified reward tier
    function invest (uint256 tierIndex) external {
        isInvestor();
        isState(Utils.State.Ongoing);
        require(!paused && !fundingExpired(), "Paused or expired");
        Utils.RewardTier memory r = rewardTiers[tierIndex];
		fundingTokenContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment);
        r.tokenId = dopotRewardContract.mintToken(msg.sender, r.hash, Utils.rewardTierToBytes(r));
        IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Someone invested in your project", getRole(CREATOR_ROLE), 3);
        IProjectFactory(addrProjectFactory).emitProjectInvested(msg.sender, r.tokenId);
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
        changeState(Utils.State.Successful);
    }

    // Investor requests refund for rewards of specified tier
    function refund(uint256 tierIndex) external {
        isInvestor();
        require(!paused && (fundingExpired() || state == Utils.State.Ongoing || state == Utils.State.Cancelled));
        uint tokenId = rewardTiers[tierIndex].tokenId;
        dopotRewardContract.burn(msg.sender, tokenId, 1);
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, rewardTiers[tierIndex].investment);
        IProjectFactory(addrProjectFactory).emitProjectRefunded(msg.sender, tokenId);
    }

    function changeState(Utils.State newState) public onlyRole(REVIEWER_ROLE) {
        state = newState;
        if((newState == Utils.State.Ongoing) && Utils.isDeadlineRange(fundRaisingDeadline)) {
            fundRaisingDeadline += block.timestamp;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Now ongoing", getRole(CREATOR_ROLE), 3);
        }
        IProjectFactory(addrProjectFactory).emitChangedState(newState);
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

