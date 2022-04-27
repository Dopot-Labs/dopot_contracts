// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Project.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable, Initializable {
    IDopotReward dopotRewardContract;
    address dopotRewardAddress;
    //address immutable dptTokenContract;
    address immutable fundingTokenContract;
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
        dopotRewardAddress = _rewardContract;
    }

    constructor(address _fundingTokenContract /*, address _dptTokenContract*/) {
        period = 39272; // Polygon blocks per day
        projectLimit = 20;
        currentPeriodEnd = block.number + period;
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
    }
 
    function createProject(uint fundRaisingDeadline, string memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory survey) external returns (address) {
        updatePeriod();
        uint totalAmount = currentPeriodAmount + 1;
        require(totalAmount >= currentPeriodAmount, 'overflow');

        require(currentPeriodAmount < projectLimit, 'Project limit reached for this period');
        currentPeriodAmount += 1;

        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        Project(projectClone).initialize(payable(msg.sender), payable(this.owner()), fundRaisingDeadline, _projectMedia, _rewardTiers, survey, fundingTokenContract, dopotRewardAddress /*, tokenContract*/);
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