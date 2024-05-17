// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "./Project.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Utils.sol";

// Interface to interact with PUSH protocol
interface IPUSHCommInterface {
    function sendNotification(address _channel, address _recipient, bytes calldata _identity) external;
}

contract ProjectFactory is Ownable, Initializable {
    using SafeERC20 for IERC20;
    IDopotReward dopotRewardContract;

    address immutable public projectImplementation;
    address epnsContractAddress;
    address epnsChannelAddress;
    address[] public projects;

    // Get projects count
    function getProjectsLength() external view returns (uint256) {
        return projects.length;
    }

    event ProjectCreated(address indexed creator, address indexed project);
    event ProjectRewardTierAdded(address indexed project, string hash, uint256 investment, uint256 supply);
    event ProjectInvested(address indexed project, address indexed investor, uint indexed tokenId);
    event ProjectRefunded(address indexed project, address indexed investor, uint indexed tokenId);
    event ChangedState(Utils.State newState, address project);
    event Staked(address staker, uint256 amount);
    event Unstaked(address unstaker);
    event ToggledPause(bool pause);
    event AddedRewardTier(string hash, uint256 investment, uint256 supply);
    event PostponedDeadline(uint256 postponeAmount);
    
    event InsurancePaidOut(address recipient, uint256 amount);
    event RewardContractSet(address rewardContract);
    event EpnsAddressSet(address epnsContractAddress, address epnsChannelAddress);
    event ProjectParamsSet(uint256 period, uint256 projectLimit, uint256 _rewardsLimit, uint256 postponeAmount, uint256 postponeFee, uint256 postponeThreshold, uint256 insurance, uint256 projectWithdrawalFee, uint256 projectStakingReward);
    event AddrParamSet(address fundingTokenAddress, address dptTokenAddress, address dptUniPoolAddress, address reviewer);

    uint256 internal currentPeriodEnd; // block which the current period ends at
    uint256 public currentPeriodAmount; // amount of projects already created this period
    Utils.AddrParams addrParams;
    Utils.ProjectParams projectParams = Utils.ProjectParams(0, 
    4,              // rewardsLimit
    20,             // projectLimit
    30 days,        // postponeAmount
    4/100 * 1e18,   // postponeFee
    2/100 * 1e18,   // projectWithdrawalFee
    1/100 * 1e18,   // projectStakingReward
    1/100 * 1e18,   // insurance
    51/100 * 1e18,  // postponeThreshold
    337510);         // Arbitrum blocks per day
    
    uint256 constant maxFee = 10/100 * 1e18; // max limit for fees
    error FundraisingValueError();
    
    // Modifier to check if _addr is a project
    modifier isProject(address _addr){
        bool found = false;
        for (uint i = 0; i < projects.length; i++) {
            if (projects[i] == _addr) {
                found = true;
                break;
            }
        }
        require(found);
        _;
    }

    // External function to emit event ProjectRewardTierAdded
    function emitProjectRewardTierAdded(string calldata _hash, uint256 _investment, uint256 _supply) external isProject(msg.sender){
        emit ProjectRewardTierAdded(msg.sender, _hash, _investment, _supply);
    }

    // External function to emit event ProjectInvested
    function emitProjectInvested(address investor, uint tokenId) external isProject(msg.sender){
        emit ProjectInvested(msg.sender, investor, tokenId);
    }

    // External function to emit event ProjectRefunded
    function emitProjectRefunded(address investor, uint tokenId) external isProject(msg.sender){
        emit ProjectRefunded(msg.sender, investor, tokenId);
    }

    // External function to emit event ChangedState
    function emitChangedState(Utils.State newState) external isProject(msg.sender){
        emit ChangedState(newState, msg.sender);
    }

    // External function to emit event Staked
    function emitStaked(address staker, uint256 amount) external isProject(msg.sender){
        emit Staked(staker, amount);
    }

    // External function to emit event Unstaked
    function emitUnstaked(address unstaker) external isProject(msg.sender){
        emit Unstaked(unstaker);
    }

    // External function to emit event ToggledPause
    function emitToggledPause(bool pause) external isProject(msg.sender){
        emit ToggledPause(pause);
    }

    // External function to emit event PostponedDeadline
    function emitPostponedDeadline(uint256 postponeAmount) external isProject(msg.sender){
        emit PostponedDeadline(postponeAmount);
    }

    // Set the factory's reward contract
    function setRewardContract(address _rewardContract) external onlyOwner{
        dopotRewardContract = IDopotReward(_rewardContract);
        addrParams.dopotRewardAddress = _rewardContract;
        emit RewardContractSet(_rewardContract);
    }

    // Set the factory's EPNS addresses
    function setEpnsAddresses(address _epnsContractAddress, address _epnsChannelAddress) external onlyOwner {
        epnsContractAddress = _epnsContractAddress;
        epnsChannelAddress = _epnsChannelAddress;
        emit EpnsAddressSet(_epnsContractAddress, _epnsChannelAddress);
    }

    // Set the factory's project parameters
    function setProjectParams(uint256 _period, uint256 _projectLimit, uint256 _rewardsLimit, uint256 _postponeAmount, uint256 _postponeFee,  uint256 _postponeThreshold, uint256 _insurance, uint256 _projectWithdrawalFee, uint256 _projectStakingReward) external onlyOwner {
        require(_projectWithdrawalFee <= maxFee && _postponeFee <= maxFee && _insurance <= maxFee, "Fee too high");
        projectParams.period = _period;
        projectParams.projectLimit = _projectLimit;
        projectParams.projectWithdrawalFee = _projectWithdrawalFee;
        projectParams.projectStakingReward = _projectStakingReward;
        projectParams.rewardsLimit = _rewardsLimit;
        projectParams.postponeFee = _postponeFee;
        projectParams.insurance = _insurance;
        projectParams.postponeAmount = _postponeAmount;
        projectParams.postponeThreshold = _postponeThreshold;
        emit ProjectParamsSet(_period, _projectLimit, _rewardsLimit, _postponeAmount, _postponeFee,  _postponeThreshold, _insurance, _projectWithdrawalFee, _projectStakingReward);
    }

    // Set the factory's address parameters
    function setAddrParam(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress, address _reviewer) external onlyOwner {
        if(addrParams.fundingTokenAddress == address(0)) addrParams.fundingTokenAddress = _fundingTokenAddress;
        if(addrParams.dptTokenAddress == address(0)) addrParams.dptTokenAddress = _dptTokenAddress;
        if(addrParams.dptUniPoolAddress == address(0)) addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        addrParams.reviewer = _reviewer;
        emit AddrParamSet(addrParams.fundingTokenAddress, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _reviewer);
    }
    
    // Factory constructor
    constructor(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress) { // TODO: deploy to arbitrum with 0x0 as dpt token and pool
        currentPeriodEnd = block.number + projectParams.period;
        projectImplementation = address(new Project());
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        addrParams.reviewer = msg.sender;
        epnsContractAddress = 0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa;
        epnsChannelAddress = 0x63381E4b8fE26cb1f55cc38e8369990594E017b1; // TODO: create and change to arbitrum one
    }

    // Create a new project
    function createProject(uint256 goal, uint256 fundRaisingDeadline) external returns (address) {
        updatePeriod();
        uint256 totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(currentPeriodAmount < projectParams.projectLimit, 'Project limit reached for this period');
        require(goal >= 100 * (10**18), "Min goal is 100 DAI");
        if(fundRaisingDeadline != 45 days && fundRaisingDeadline != 65 days && fundRaisingDeadline != 90 days) revert FundraisingValueError(); // fundRaisingDeadline: 45 / 65 / 90 days in number of seconds
        currentPeriodAmount += 1;
        projectParams.goal = goal;
        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        addrParams.creator = msg.sender;
        Project(projectClone).initialize(msg.sender, addrParams, fundRaisingDeadline, projectParams);
        projects.push(projectClone);
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }

    // Payout a user from the factory's fundingToken insurance fund
    function insurancePayout(address recipient, uint256 amount) external onlyOwner {
        IERC20(addrParams.fundingTokenAddress).safeTransfer(recipient, amount);
        emit InsurancePaidOut(recipient, amount);
    }

    // Send a norification to recipient with PUSH protocol
    function sendNotif(string memory _title, string memory _body, address _recipient, uint256 _payloadType) public isProject(msg.sender) {
        string memory separator = "+";
        IPUSHCommInterface(epnsContractAddress).sendNotification(
            epnsChannelAddress, //set channel via dApp and put it's value -> then once contract is deployed, add contract address as delegate for channel
            _recipient == address(0) ? address(this) : _recipient, // address(this) if Broadcast or Subset. For Targetted put the address to which you want to send
            bytes(
                string(
                    abi.encodePacked(
                        "0", // storage type = minimal
                        separator,
                        _payloadType, // payload type (1, 3 or 4) = (Broadcast, targeted or subset)
                        separator,
                        _title,
                        separator,
                        _body
                    )
                )
            )
        );
    }

    // Keep track of periods to enforce a max projects number per period
    function updatePeriod() internal {
        if(currentPeriodEnd < block.number) {
            currentPeriodEnd = block.number + projectParams.period;
            currentPeriodAmount = 0;
        }
    }
}