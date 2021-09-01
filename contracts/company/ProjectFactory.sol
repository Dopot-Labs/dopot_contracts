// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Project.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract ProjectFactory {

    address immutable projectImplementation;
    address payable admin;

    constructor() {
        projectImplementation = address(new Project());
        admin = msg.sender;
    }

    event ProjectCreated(address creator, address project);

    function createProject(uint memory fundRaisingDeadline, uint memory goalAmount, uint memory minimum)
    external // limit to only approved users
    returns (address) {
        address projectClone = Clones.clone(projectImplementation);
        Project(projectClone).initialize(msg.sender, admin, fundRaisingDeadline, goalAmount, minimum);
        emit ProjectCreated(msg.sender, projectClone);
        return projectClone;
    }
}