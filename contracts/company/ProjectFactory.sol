// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "./Project.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Utils.sol";

interface IPUSHCommInterface {
    function sendNotification(address _channel, address _recipient, bytes calldata _identity) external;
}

contract ProjectFactory is Ownable, Initializable {
    using SafeERC20 for IERC20;
    IDopotReward dopotRewardContract;
    
    address public projectImplementation;
    uint256 public projectImplementationVersion = 1;
    address epnsContractAddress;
    address epnsChannelAddress;
    struct ProjectVersion {
        address projectAddress;
        uint256 version;
    }
    ProjectVersion[] public projectsVersions;
    function getProjectsLength() external view returns (uint256) {
        return projectsVersions.length;
    }

    event ProjectCreated(address indexed creator, address indexed project);
    event ProjectRewardTierAdded(address indexed project, string hash);
    event ProjectInvested(address indexed project, address indexed investor, uint indexed tokenId);
    event ProjectRefunded(address indexed project, address indexed investor, uint indexed tokenId);
    event ChangedState(Utils.State newState, address project);

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
    39272);         // Polygon blocks per day TODO: change to arbitrum one
    error FundraisingValueError();
    modifier isProject(address _addr){
        bool found = false;
        for (uint i = 0; i < projectsVersions.length; i++) {
            if (projectsVersions[i].projectAddress == _addr) {
                found = true;
                break;
            }
        }
        require(found);
        _;
    }
    function emitProjectRewardTierAdded(string calldata _hash) external isProject(msg.sender){
        emit ProjectRewardTierAdded(msg.sender, _hash);
    }
    function emitProjectInvested(address investor, uint tokenId) external isProject(msg.sender){
        emit ProjectInvested(msg.sender, investor, tokenId);
    }
    function emitProjectRefunded(address investor, uint tokenId) external isProject(msg.sender){
        emit ProjectRefunded(msg.sender, investor, tokenId);
    }
    function emitChangedState(Utils.State newState) external isProject(msg.sender){
        emit ChangedState(newState, msg.sender);
    }
    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }
    function setRewardContract(address _rewardContract) external onlyOwner{
        dopotRewardContract = IDopotReward(_rewardContract);
        addrParams.dopotRewardAddress = _rewardContract;
    }
    function setEpnsAddresses(address _epnsContractAddress, address _epnsChannelAddress) external onlyOwner {
        epnsContractAddress = _epnsContractAddress;
        epnsChannelAddress = _epnsChannelAddress;
    }
    function setProjectParams(uint256 _period, uint256 _projectLimit, uint256 _rewardsLimit, uint256 _postponeAmount, uint256 _postponeFee,  uint256 _postponeThreshold, uint256 _insurance, uint256 _projectWithdrawalFee, uint256 _projectStakingReward) external onlyOwner {
        projectParams.period = _period;
        projectParams.projectLimit = _projectLimit;
        projectParams.projectWithdrawalFee = _projectWithdrawalFee;
        projectParams.projectStakingReward = _projectStakingReward;
        projectParams.rewardsLimit = _rewardsLimit;
        projectParams.postponeFee = _postponeFee;
        projectParams.insurance = _insurance;
        projectParams.postponeAmount = _postponeAmount;
        projectParams.postponeThreshold = _postponeThreshold;
    }

    function setAddrParam(address _fundingTokenAddress, address _dopotRewardAddress, address _dptTokenAddress, address _dptUniPoolAddress, address _reviewer) external onlyOwner {
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dopotRewardAddress = _dopotRewardAddress;
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        addrParams.reviewer = _reviewer;
    }
    
    constructor(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress) { // TODO: deploy to arbitrum with 0x0 as dpt token and pool
        currentPeriodEnd = block.number + projectParams.period;
        projectImplementation = address(new Project());
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        addrParams.reviewer = msg.sender;
        epnsContractAddress = 0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa; // mumbai TODO: change to arbitrum one
        epnsChannelAddress = 0x340cb0AA007F2ECbF6fCe3cd8929a22429893213; // TODO: create and change to arbitrum one
    }
    // fundRaisingDeadline: 45 / 65 / 90 days in number of seconds
    function createProject(uint256 goal, uint256 fundRaisingDeadline) external returns (address) {
        updatePeriod();
        uint256 totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(currentPeriodAmount < projectParams.projectLimit, 'Project limit reached for this period');
        if(fundRaisingDeadline != 45 days && fundRaisingDeadline != 65 days && fundRaisingDeadline != 90 days) revert FundraisingValueError();
        currentPeriodAmount += 1;
        projectParams.goal = goal;
        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        addrParams.creator = msg.sender;
        Project(projectClone).initialize(msg.sender, addrParams, fundRaisingDeadline, projectParams);
        projectsVersions.push( ProjectVersion(projectClone, projectImplementationVersion) );
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }

    function insurancePayout(address recipient, uint256 amount) external onlyOwner {
         IERC20(addrParams.fundingTokenAddress).safeTransfer(recipient, amount);
    }

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

    function updatePeriod() internal {
        if(currentPeriodEnd < block.number) {
            currentPeriodEnd = block.number + projectParams.period;
            currentPeriodAmount = 0;
        }
    }
}