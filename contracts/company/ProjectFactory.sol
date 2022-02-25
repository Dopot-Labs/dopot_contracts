// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "./Project.sol";
import "../IPFS.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable{

    address payable public immutable admin;

    address public projectImplementation;
    uint public projectImplementationVersion;
    
    //address immutable dptTokenContract;
    address immutable fundingTokenContract;

    
    mapping(address => uint) public projectsVersions;
    event ProjectCreated(address creator, address project); 

    function setProjectImplementationAddress(address _projectImplementation) external onlyOwner {
        projectImplementation = _projectImplementation;
        projectImplementationVersion ++;
    }

    constructor(address _fundingTokenContract/*, address _dptTokenContract*/) { 
        projectImplementation = address(new Project());
        projectImplementationVersion = 1;

        admin = payable(msg.sender);
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
    }

 
    function createProject(uint fundRaisingDeadline, uint goalAmount, IPFS.Multihash[] memory _projectMedia, IPFS.RewardTier[] memory _rewardTiers) external returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        Project(projectClone).initialize(payable(msg.sender), admin, fundRaisingDeadline, goalAmount, _projectMedia, _rewardTiers,  fundingTokenContract /*, tokenContract*/);
        projectsVersions[projectClone] = projectImplementationVersion;
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }
}