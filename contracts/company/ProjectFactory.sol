// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "./Project.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Utils.sol";

contract ProjectFactory is Ownable, Initializable {
    using SafeERC20 for IERC20;
    IDopotReward dopotRewardContract;
    string frontendHash;
    
    address public projectImplementation;
    uint256 public projectImplementationVersion = 1;
    
    struct ProjectVersion {
        address projectAddress;
        uint256 version;
    }
    ProjectVersion[] public projectsVersions;
    function getProjectsLength() external view returns (uint256) {
        return projectsVersions.length;
    }

    event ProjectCreated(address indexed creator, address indexed project, string projectMedia);
    event ProjectRewardTierAdded(string ipfshash);
    event FrontendUpdated(string frontendHash);
    uint256 internal currentPeriodEnd; // block which the current period ends at
    uint256 public currentPeriodAmount; // amount of projects already created this period
    Utils.AddrParams addrParams;
    Utils.ProjectParams projectParams = Utils.ProjectParams(0, 4, 20, 30 days, 1/100 * 1e18, 4/100 * 1e18, 3/100 * 1e18, 1/100 * 1e18, 51/100 * 1e18, 39272); // Polygon blocks per day
    error FundraisingValueError();
    function emitProjectRewardTierAdded(string calldata _ipfshash) external{
        emit ProjectRewardTierAdded(_ipfshash);
    }
    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }
    function setFrontendHash(string memory _frontendHash) external onlyOwner {
        frontendHash = _frontendHash;
        Utils.sendNotif("Website update", string(abi.encodePacked("New decentralized version available at ipfs://", _frontendHash)), address(0), 1, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
        emit FrontendUpdated(_frontendHash);
    }
    function setRewardContract(address _rewardContract) external onlyOwner{
        dopotRewardContract = IDopotReward(_rewardContract);
        addrParams.dopotRewardAddress = _rewardContract;
    }
    function setEpnsAddresses(address _epnsContractAddress, address _epnsChannelAddress) external onlyOwner {
        addrParams.epnsContractAddress = _epnsContractAddress;
        addrParams.epnsChannelAddress = _epnsChannelAddress;
    }
    function setProjectParams(uint256 _period, uint256 _projectLimit, uint256 _rewardsLimit, uint256 _postponeAmount, uint256 _postponeFee,  uint256 _postponeThreshold, uint256 _insurance, uint256 _projectWithdrawalFee, uint256 _projectDiscountedWithdrawalFee) external onlyOwner {
        projectParams.period = _period;
        projectParams.projectLimit = _projectLimit;
        projectParams.projectWithdrawalFee = _projectWithdrawalFee;
        projectParams.projectDiscountedWithdrawalFee = _projectDiscountedWithdrawalFee;
        projectParams.rewardsLimit = _rewardsLimit;
        projectParams.postponeFee = _postponeFee;
        projectParams.insurance = _insurance;
        projectParams.postponeAmount = _postponeAmount;
        projectParams.postponeThreshold = _postponeThreshold;
    }
    
    constructor(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress) {
        currentPeriodEnd = block.number + projectParams.period;
        projectImplementation = address(new Project());
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        addrParams.epnsContractAddress = 0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa; // mumbai
        addrParams.epnsChannelAddress = 0x277E69166D01DC241700B0e33Cd253fDDC07142E;
    }
    // fundRaisingDeadline: 45 / 65 / 90 days in number of seconds
    function createProject(uint256 goal, uint256 fundRaisingDeadline, string memory _projectMedia) external returns (address) {
        updatePeriod();
        uint256 totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(currentPeriodAmount < projectParams.projectLimit, 'Project limit reached for this period');
        if(fundRaisingDeadline != 45 days && fundRaisingDeadline != 65 days && fundRaisingDeadline != 90 days) revert FundraisingValueError();
        currentPeriodAmount += 1;
        projectParams.goal = goal;
        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        Project(projectClone).initialize(addrParams, payable(msg.sender), payable(this.owner()), fundRaisingDeadline, _projectMedia, projectParams);
        projectsVersions.push( ProjectVersion(projectClone, projectImplementationVersion) );
        emit ProjectCreated(msg.sender, projectClone, _projectMedia);
        return projectClone;
    }

    function insurancePayout(address recipient, uint256 amount) external onlyOwner {
         IERC20(addrParams.fundingTokenAddress).safeTransfer(recipient, amount);
    }


    function updatePeriod() internal {
        if(currentPeriodEnd < block.number) {
            currentPeriodEnd = block.number + projectParams.period;
            currentPeriodAmount = 0;
        }
    }
}