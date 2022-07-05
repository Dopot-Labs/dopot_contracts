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

    uint public period; // how many blocks before limit resets
    uint public projectLimit; // max project to create per period
    uint internal currentPeriodEnd; // block which the current period ends at
    uint public currentPeriodAmount; // amount of projects already created this period
    IPFS.AddrParams addrParams;
    IPFS.ProjectParams projectParams;

    function setProjectLimit(uint _period, uint _projectLimit) external onlyOwner {
        period = _period;
        projectLimit = _projectLimit;
    }
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

    function setProjectParams(uint _projectWithdrawalFee, uint _projectDiscountedWithdrawalFee, uint _projectMediaLimit, uint _rewardsLimit) external onlyOwner {
        projectParams.projectWithdrawalFee = _projectWithdrawalFee;
        projectParams.projectDiscountedWithdrawalFee = _projectDiscountedWithdrawalFee;
        projectParams.projectMediaLimit = _projectMediaLimit;
        projectParams.rewardsLimit = _rewardsLimit;
    }
    
    constructor(address _fundingTokenAddress, address _dptTokenAddress, address _dptUniPoolAddress) {
        period = 39272; // Polygon blocks per day
        projectLimit = 20;
        currentPeriodEnd = block.number + period;
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;
        projectParams.projectWithdrawalFee = 18/1000 * 1e18; // 1.8%
        projectParams.projectDiscountedWithdrawalFee = 1/100 * 1e18; // 1%
        projectParams.rewardsLimit = 4;
        addrParams.dptTokenAddress = _dptTokenAddress;
        addrParams.fundingTokenAddress = _fundingTokenAddress;
        addrParams.dptUniPoolAddress = _dptUniPoolAddress;
        
    }
 
    function createProject(uint fundRaisingDeadline, string memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory survey) external returns (address) {
        updatePeriod();
        uint totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');
        require(_rewardTiers.length <= projectParams.rewardsLimit, "RL");
        require(currentPeriodAmount < projectLimit, 'Project limit reached for this period');

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
            currentPeriodEnd = block.number + period;
            currentPeriodAmount = 0;
        }
    }
}