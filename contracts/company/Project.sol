// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Project is Initializable, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    using SafeMath for uint256;
    using SafeMath for uint;
    address payable public admin;
    address payable public creator;
    uint256 private value;
    uint public amountGoal;
    uint public raiseBy;
    uint public minimumContribution;
    
    enum State {
        PendingApproval,
        Rejected,
        Ongoing,
        Successful,
        Expired
    }
    State public state;
    mapping (address => uint) public investments;

    modifier isState(State _state){
        require(state == _state);
        _;
    }

    modifier isCreator() {
        require(msg.sender == creator);
        _;
    }
    modifier isAdmin() {
        require(msg.sender == admin);
        _;
    }

    function initialize(address payable _creator, address payable _admin, uint fundRaisingDeadline, uint goalAmount, uint minimum) public initializer  {
        creator = _creator;
        admin = _admin;
        amountGoal = goalAmount;
        raiseBy = fundRaisingDeadline;
        minimumContribution = minimum;
        state = State.PendingApproval;

        _setupRole(DEFAULT_ADMIN_ROLE, _creator);
    }

    
    function invest() external isState(State.Ongoing) payable {
        require(msg.sender != creator);
        require(msg.value >= minimumContribution);
        investments[msg.sender] += msg.value;
    }

    function checkFundingChange() private {
        if (address(this).balance >= amountGoal) {
            state = State.Successful;
            withdraw();
        }
    }

    function withdraw() private {
        uint amount = address(this).balance;
        // % fee to us  ?
        (bool success,) = creator.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function transfer(address payable _to, uint _amount) external isCreator  {
        (bool success,) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    function getRefund() external isState(State.Expired) returns (bool){
        require(investments[msg.sender] > 0);
        uint amount = investments[msg.sender];
        if (amount > 0){
            investments[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)){
                investments[msg.sender] = amount;
                return false;
            }
        }
        return true;
        }


    function changeState(State newState) external isAdmin{
        state = newState;
    }







    event ValueChanged(uint256 newValue);

    function store(uint256 newValue) external {
        value = newValue;
        emit ValueChanged(newValue);
    }

    function retrieve() external view returns (uint256) {
        return value;
    }

}