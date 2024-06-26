// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface to call ProjectFactory
interface IProjectFactory {
    function emitProjectRewardTierAdded(string calldata hash, uint256 investment, uint256 supply) external;
    function emitProjectInvested(address investor, uint tokenId) external;
    function emitProjectRefunded(address investor, uint tokenId) external;
    function sendNotif(string memory title, string memory body, address recipient, uint256 payloadType) external;
    function emitChangedState(Utils.State newState) external;
    function emitStaked(address staker, uint256 amount) external;
    function emitUnstaked(address unstaker) external;
    function emitToggledPause(bool pause) external;
    function emitPostponedDeadline(uint256 postponeAmount) external;
}

// Interface to call DopotReward
interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, bytes calldata rewardTier) external returns(uint256);
    function burn(address account, uint256 id, uint256 value) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function whitelistProject(address project) external;
    function getRewardData(uint256 id) external view returns (Utils.RewardTier memory);
}

contract Project is Initializable, Ownable, ReentrancyGuard {
    IDopotReward dopotRewardContract;
    IERC20 fundingTokenContract;
    using SafeERC20 for IERC20;
    uint256 public fundRaisingDeadline;
    address addrProjectFactory;
    Utils.AddrParams public addrParams;
    Utils.ProjectParams public projectParams;
    Utils.RewardTier[] public rewardTiers;
    bool public paused;
    Utils.State public state;
    mapping(address => uint) public stakes;
    uint public totalStaked;
    uint32 constant twapInterval = 60*60*24;

    // Check project's stake
    function isState(Utils.State _state) internal view {
        require(state == _state, "Incorrect State");
    }

    // Check if dpt token addresses were ever set
    function dptAddressesSet() public view returns (bool) {
        return (addrParams.dptTokenAddress != address(0x0) && addrParams.dptUniPoolAddress != address(0x0));
    }

    // Estimate current withdraw fee amount
    function getWithdrawalFee() public view returns (uint256) {
        uint256 balance = fundingTokenContract.balanceOf(address(this));
        return Utils.estimateAmountOut(addrParams.fundingTokenAddress, addrParams.dptTokenAddress, (balance  *  projectParams.projectWithdrawalFee  / 1e18), addrParams.dptUniPoolAddress, twapInterval);
    }

    // Estimate current staking rewards
    function getStakingRewards() public view returns (uint256) {
        uint256 balance = fundingTokenContract.balanceOf(address(this));
        return Utils.estimateAmountOut(addrParams.fundingTokenAddress, addrParams.dptTokenAddress, (balance  *  projectParams.projectStakingReward  / 1e18),  addrParams.dptUniPoolAddress, twapInterval);
    }

    // Stake dpt tokens in the project
    function stake(uint amount) external nonReentrant {
        require(dptAddressesSet(), "Dpt addresses not set");
        require(msg.sender == tx.origin, "Caller must be an EOA");
        require(amount > 0, "Must stake above 0");
        isState(Utils.State.Ongoing);
        require(!paused && !fundingExpired(), "Paused or expired");
        require(fundingTokenContract.balanceOf(address(this)) < projectParams.goal, "Goal already reached");
        IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;
        totalStaked += amount;
        IProjectFactory(addrProjectFactory).emitStaked(msg.sender, amount);
    }

    // Unstake a previous dpt stake and receive rewards
    function unstake() external nonReentrant {
        require(dptAddressesSet(), "Dpt addresses not set");
        require(msg.sender == tx.origin, "Caller must be an EOA");
        require(stakes[msg.sender] > 0, "No stake");
        require((state == Utils.State.Successful || state == Utils.State.Cancelled || fundingExpired()), "Ongoing");
        uint stakeAmount = stakes[msg.sender];
        if(state == Utils.State.Successful && msg.sender != addrParams.creator){
            uint256 dptBalance = IERC20(addrParams.dptTokenAddress).balanceOf(address(this)); //Includes staking rewards
            uint256 creatorStake = stakes[addrParams.creator];
            //User's staking reward
            IERC20(addrParams.dptTokenAddress).safeTransfer(msg.sender, stakeAmount * ((dptBalance - totalStaked - creatorStake) / (totalStaked - creatorStake)));
        }
        IERC20(addrParams.dptTokenAddress).safeTransfer(msg.sender, stakeAmount);
        stakes[msg.sender] = 0;
        totalStaked -= stakeAmount;
        IProjectFactory(addrProjectFactory).emitUnstaked(msg.sender);
    }

    // Get reward tiers count
    function getTiersLength() external view returns (uint256) {
        return rewardTiers.length;
    }

    // Modifier to check if sender is a certain _addr
    modifier onlyRole(address _addr){
        require(msg.sender == _addr, "Wrong role");
        _;
    }

    // Pause/unpause the contract
    function togglePause() external onlyRole(addrParams.reviewer) {
        paused = !paused;
        IProjectFactory(addrProjectFactory).emitToggledPause(paused);
    }
    
    // Check if sender is normal user (investor)
    function isInvestor() internal view {
        require(addrParams.creator != msg.sender && addrParams.reviewer != msg.sender, "Creator or reviewer");
    }

    // Initialize the project
    function initialize(address _creator, Utils.AddrParams calldata _addrParams, uint256 _fundRaisingDeadline, Utils.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        fundingTokenContract = IERC20(_addrParams.fundingTokenAddress);
        addrProjectFactory = msg.sender;
        addrParams = _addrParams;
        addrParams.creator = _creator;
        fundRaisingDeadline = _fundRaisingDeadline;
        projectParams = _projectParams;
    }

    // Check if provided hash is unique in project's reward tiers
    function isHashUnique(string memory hash) public view returns (bool) {
        for (uint256 i = 0; i < rewardTiers.length; i++) {
            if (keccak256(abi.encodePacked(rewardTiers[i].hash)) == keccak256(abi.encodePacked(hash))) {
                return false;
            }
        }
        return true;
    }

    // Add a reward tier to the project
    function addRewardTier(string memory _hash, uint256 _investment, uint256 _supply) external onlyRole(addrParams.creator) nonReentrant {
        require(!paused, "Paused");
        require(rewardTiers.length < projectParams.rewardsLimit, "Limit");
        require(isHashUnique(_hash), "Duplicate");
        rewardTiers.push(Utils.RewardTier(_hash, _investment, _supply, address(0)));
        IProjectFactory(addrProjectFactory).emitProjectRewardTierAdded(_hash, _investment, _supply);
    }

    // Internally check if fundraising deadline reached, if so change state and send notification
    function fundingExpired() internal returns (bool){
        uint256 deadline = fundRaisingDeadline;
        if(Utils.isDeadlineRange(deadline)) return false;
        if((block.timestamp > deadline) && state == Utils.State.Ongoing) {
            state = Utils.State.Expired;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Tier deadline reached", addrParams.creator, 3);
            IProjectFactory(addrProjectFactory).emitChangedState(Utils.State.Expired);
        }
        return (block.timestamp > deadline);
    }

    // Creator pays to postpone deadline
    function postponeDeadline() external onlyRole(addrParams.creator) nonReentrant{
        isState(Utils.State.Ongoing);
        address _dptTokenAddress = addrParams.dptTokenAddress;
        uint256 fundingTokenBalance = fundingTokenContract.balanceOf(address(this));
        require(!paused && fundingTokenBalance >= (projectParams.goal  *  projectParams.postponeThreshold / 1e18));
        if(dptAddressesSet())
            IERC20(_dptTokenAddress).safeTransferFrom(msg.sender, addrParams.reviewer, Utils.estimateAmountOut(
                addrParams.fundingTokenAddress, addrParams.dptTokenAddress, (projectParams.goal - fundingTokenBalance)  *  projectParams.postponeFee  / 1e18, addrParams.dptUniPoolAddress, twapInterval));
        fundRaisingDeadline += projectParams.postponeAmount;
        IProjectFactory(addrProjectFactory).emitPostponedDeadline(projectParams.postponeAmount);
    }

    // User invests in specified reward tier
    function invest (uint256 tierIndex) external nonReentrant {
        isInvestor();
        isState(Utils.State.Ongoing);
        require(!paused && !fundingExpired(), "Paused or expired");
        Utils.RewardTier memory r = rewardTiers[tierIndex];
		fundingTokenContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment);
        uint tokenId = dopotRewardContract.mintToken(msg.sender, r.hash, Utils.rewardTierToBytes(r));
        rewardTiers[tierIndex] = r;
        IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Someone invested in your project", addrParams.creator, 3);
        IProjectFactory(addrProjectFactory).emitProjectInvested(msg.sender, tokenId);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw() external onlyRole(addrParams.creator) nonReentrant {
        uint256 balance = fundingTokenContract.balanceOf(address(this));
        require(!paused && balance >= projectParams.goal);
        uint256 insuranceAmount = balance * projectParams.insurance / 1e18;

        if(dptAddressesSet()){
            uint stakeAmount = stakes[msg.sender];
            if(stakeAmount > 0){
                stakes[msg.sender] = 0;
                IERC20(addrParams.dptTokenAddress).safeTransfer(msg.sender, stakeAmount);
                totalStaked -= stakeAmount;
            }
            IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, addrParams.reviewer, getWithdrawalFee());
            IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, address(this), getStakingRewards());
        }
        //Project's funds
        fundingTokenContract.safeTransfer(msg.sender, balance - insuranceAmount);
        //Insurance
        fundingTokenContract.safeTransfer(addrProjectFactory, insuranceAmount);
        state = Utils.State.Successful;
        IProjectFactory(addrProjectFactory).emitChangedState(state);
    }

    // Investor requests refund for specified reward
    function refund(uint256 tokenId) external {
        isInvestor();
        require(!paused && (fundingExpired() || state == Utils.State.Ongoing || state == Utils.State.Cancelled), "Paused/Successful");
        dopotRewardContract.burn(msg.sender, tokenId, 1);
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, dopotRewardContract.getRewardData(tokenId).investment);
        IProjectFactory(addrProjectFactory).emitProjectRefunded(msg.sender, tokenId);
    }

    // Change the project's state
    function changeState(Utils.State newState) public onlyRole(addrParams.reviewer) {
        state = newState;
        if((newState == Utils.State.Ongoing) ) {
            require(Utils.isDeadlineRange(fundRaisingDeadline), "Invalid deadline");
            fundRaisingDeadline += block.timestamp;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Now ongoing", addrParams.creator, 3);
        }
        IProjectFactory(addrProjectFactory).emitChangedState(newState);
    }

    // Handle ERC1155 received
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // Handle ERC1155Batch received
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

