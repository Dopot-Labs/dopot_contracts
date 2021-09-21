// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "./Project.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectFactory is Ownable{

    address public immutable projectImplementation;
    address payable public immutable admin;
    //address immutable dptTokenContract;
    address immutable fundingTokenContract;

    constructor(address _fundingTokenContract/*, address _dptTokenContract*/) {
        projectImplementation = address(new Project());
        admin = payable(msg.sender);
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
    }

    event ProjectCreated(address creator, address project);

    function createProject(uint fundRaisingDeadline, uint goalAmount, uint minimum) external returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        Project(projectClone).initialize(payable(msg.sender), admin, fundRaisingDeadline, goalAmount, minimum, fundingTokenContract /*, tokenContract*/);
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }
}