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
    event ProjectCreated(address indexed creator, address indexed project, string[] projectMedia, IPFS.RewardTier[] rewardTiers, string survey); 
    event FrontendUpdated(string frontendHash);

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
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;

        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
    }
 
    function createProject(uint fundRaisingDeadline, string[] memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory survey) external returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        dopotRewardContract.whitelistProject(projectClone);
        Project(projectClone).initialize(payable(msg.sender), payable(this.owner()), fundRaisingDeadline, _projectMedia, _rewardTiers, survey, fundingTokenContract, dopotRewardAddress /*, tokenContract*/);
        projectsVersions[projectClone] = projectImplementationVersion;
        emit ProjectCreated(msg.sender, projectClone, _projectMedia, _rewardTiers, survey);
        return projectClone;
    }
}