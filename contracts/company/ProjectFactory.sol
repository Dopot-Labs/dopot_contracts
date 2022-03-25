// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Project.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable{

    address payable public immutable admin; /// immutable ??
    
    //address immutable dptTokenContract;
    address immutable fundingTokenContract;
    address immutable rewardContract;
    
    address public projectImplementation;
    uint public projectImplementationVersion;
    mapping(address => uint) public projectsVersions;
    event ProjectCreated(address indexed creator, address indexed project); 

    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }

    constructor(address _fundingTokenContract, address _rewardContract /*, address _dptTokenContract*/) { 
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;

        admin = payable(msg.sender);
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
        rewardContract = _rewardContract;
    }

 
    function createProject(uint fundRaisingDeadline, IPFS.Multihash[] memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers, IPFS.Multihash memory survey) external returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        Project(projectClone).initialize(payable(msg.sender), admin, fundRaisingDeadline, _projectMedia, _rewardTiers, survey, fundingTokenContract /*, tokenContract*/);
        projectsVersions[projectClone] = projectImplementationVersion;
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }
}