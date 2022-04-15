// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Project.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/";
import "@openzeppelin/contracts/proxy/Clones.sol";
interface DopotReward{ function whitelistProject(address project) external; }

contract ProjectFactory is Ownable, Initializable {
    DopotReward dopotRewardContract;
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
        dopotRewardContract = DopotReward(_rewardContract);
    }

    function initialize(address _fundingTokenContract /*, address _dptTokenContract*/) public initializer {
        __Ownable_init();
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;

        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
    }
 
    function createProject(uint fundRaisingDeadline, string[] memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, string memory survey) external returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        Project(projectClone).initialize(payable(msg.sender), payable(this.owner()), fundRaisingDeadline, _projectMedia, _rewardTiers, survey, fundingTokenContract /*, tokenContract*/);
        projectsVersions[projectClone] = projectImplementationVersion;
        dopotRewardContract.whitelistProject(projectClone);
        emit ProjectCreated(msg.sender, projectClone, _projectMedia, _rewardTiers, survey);
        return projectClone;
    }
}