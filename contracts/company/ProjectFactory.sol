// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Project.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable, Initializable {
    IDopotReward dopotRewardContract;
    string frontendHash;
    
    address public projectImplementation;
    uint public projectImplementationVersion;
    mapping(address => uint) public projectsVersions;
    event ProjectCreated(address indexed creator, address indexed project, string projectMedia, IPFS.RewardTier[] rewardTiers, string survey); 
    event FrontendUpdated(string frontendHash);
    uint internal currentPeriodEnd; // block which the current period ends at
    uint public currentPeriodAmount; // amount of projects already created this period
    IPFS.AddrParams addrParams;
    IPFS.ProjectParams projectParams;

    error FundraisingValueError();
    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }
    function setFrontendHash(string memory _frontendHash) external onlyOwner {
        frontendHash = _frontendHash;
        emit FrontendUpdated(_frontendHash);
    }
    function setRewardContract(address _rewardContract) external onlyOwner{
        dopotRewardContract = IDopotReward(_rewardContract);
        addrParams.dopotRewardAddress = _rewardContract;
    }

    function setProjectParams(uint _period, uint _projectLimit, uint _projectWithdrawalFee, uint _projectDiscountedWithdrawalFee, uint _projectMediaLimit, uint _rewardsLimit, uint _postponeFee, uint _postponeAmount, uint _postponeThreshold) external onlyOwner {
        projectParams.period = _period;
        projectParams.projectLimit = _projectLimit;
        projectParams.projectWithdrawalFee = _projectWithdrawalFee;
        projectParams.projectDiscountedWithdrawalFee = _projectDiscountedWithdrawalFee;
        projectParams.projectMediaLimit = _projectMediaLimit;
        projectParams.rewardsLimit = _rewardsLimit;
        projectParams.postponeFee = _postponeFee;
        projectParams.postponeAmount = _postponeAmount;
        projectParams.postponeThreshold = _postponeThreshold;
    }
    
    constructor(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress) {
        projectParams.period = 39272; // Polygon blocks per day
        projectParams.projectLimit = 20;
        currentPeriodEnd = block.number + projectParams.period;
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;
        projectParams.projectWithdrawalFee = 18/1000 * 1e18; // 1.8%
        projectParams.projectDiscountedWithdrawalFee = 1/100 * 1e18; // 1%
        projectParams.postponeFee = 1/100 * 1e18; // 1%
        projectParams.postponeAmount = 30 days;
        projectParams.postponeThreshold = 51/100 * 1e18; // 51%
        projectParams.rewardsLimit = 4;
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        
    }
    // fundRaisingDeadline: 45 / 65 / 90 days in number of seconds
    function createProject(uint fundRaisingDeadline, string memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory survey) external returns (address) {
        updatePeriod();
        uint totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(_rewardTiers.length <= projectParams.rewardsLimit, "RL");
        require(currentPeriodAmount < projectParams.projectLimit, 'Project limit reached for this period');
        if(fundRaisingDeadline != 45 days && fundRaisingDeadline != 65 days && fundRaisingDeadline != 90 days) revert FundraisingValueError();
        currentPeriodAmount += 1;

        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        addrParams.creator = payable(msg.sender);
        addrParams.reviewer = payable(this.owner());
        Project(projectClone).initialize(addrParams, fundRaisingDeadline, _projectMedia, _rewardTiers, survey, projectParams);
        projectsVersions[projectClone] = projectImplementationVersion;
        emit ProjectCreated(msg.sender, projectClone, _projectMedia, _rewardTiers, survey);
        return projectClone;
    }

    function updatePeriod() internal {
        if(currentPeriodEnd < block.number) {
            currentPeriodEnd = block.number + projectParams.period;
            currentPeriodAmount = 0;
        }
    }
}