// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "hardhat/console.sol";
import "./Project.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract ProjectFactory is Ownable, Initializable, Utils {
    using SafeERC20 for IERC20;
    IDopotReward dopotRewardContract;
    string frontendHash;
    
    address public projectImplementation;
    uint public projectImplementationVersion = 1;
    
    struct ProjectVersion {
        address projectAddress;
        uint version;
    }
    ProjectVersion[] public projectsVersions;
    function getProjectsLength() external view returns (uint) {
        return projectsVersions.length;
    }

    event ProjectCreated(address indexed creator, address indexed project, string projectMedia); 
    event FrontendUpdated(string frontendHash);
    uint internal currentPeriodEnd; // block which the current period ends at
    uint public currentPeriodAmount; // amount of projects already created this period
    Utils.AddrParams addrParams;
    Utils.ProjectParams projectParams = Utils.ProjectParams(4, 20, 30 days, 1/100 * 1e18, 4/100 * 1e18, 3/100 * 1e18, 1/100 * 1e18, 51/100 * 1e18, 39272); // Polygon blocks per day

    error FundraisingValueError();
    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }
    function setFrontendHash(string memory _frontendHash) external onlyOwner {
        frontendHash = _frontendHash;
        Utils.sendNotif("Website update", string.concat("New decentralized version available at ipfs://", _frontendHash), address(0), 1, addrParams.epnsContractAddress, addrParams.epnsChannelAddress);
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
    function setProjectParams(uint _period, uint _projectLimit, uint _rewardsLimit, uint _postponeAmount, uint _postponeFee,  uint _postponeThreshold, uint _insurance, uint _projectWithdrawalFee, uint _projectDiscountedWithdrawalFee) external onlyOwner {
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
    function createProject(uint fundRaisingDeadline, string memory _projectMedia) external returns (address) {
        updatePeriod();
        uint totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(currentPeriodAmount < projectParams.projectLimit, 'Project limit reached for this period');
        if(fundRaisingDeadline != 45 days && fundRaisingDeadline != 65 days && fundRaisingDeadline != 90 days) revert FundraisingValueError();
        currentPeriodAmount += 1;

        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        Project(projectClone).initialize(addrParams, payable(msg.sender), payable(this.owner()), fundRaisingDeadline, _projectMedia, projectParams);
        projectsVersions.push( ProjectVersion(projectClone, projectImplementationVersion) );
        emit ProjectCreated(msg.sender, projectClone, _projectMedia);
        return projectClone;
    }

    function insurancePayout(address recipient, uint amount) external onlyOwner {
         IERC20(addrParams.fundingTokenAddress).safeTransfer(recipient, amount);
    }


    function updatePeriod() internal {
        if(currentPeriodEnd < block.number) {
            currentPeriodEnd = block.number + projectParams.period;
            currentPeriodAmount = 0;
        }
    }
}