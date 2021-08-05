// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Project is OwnableUpgradeable {
  using SafeMath for uint256;
  using SafeMath for uint;
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

  modifier checkState(State _state){
      require(state == _state);
      _;
  }

  modifier isCreator() {
      require(msg.sender == creator);
      _;
  }

  function initialize(address payable projectStarter, uint fundRaisingDeadline, uint goalAmount, uint minimum) public initializer  {
    __Context_init_unchained();
    __Ownable_init_unchained();
    creator = projectStarter;
    amountGoal = goalAmount;
    raiseBy = fundRaisingDeadline;
    minimumContribution = minimum;
    state = State.PendingApproval;
  }

  
  function invest() external checkState(State.Ongoing) payable {
    require(msg.sender != owner());
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
      (bool success,) = payable(owner()).call{value: amount}("");
      require(success, "Failed to send Ether");
  }

  function transfer(address payable _to, uint _amount) external onlyOwner  {
      (bool success,) = _to.call{value: _amount}("");
      require(success, "Failed to send Ether");
  }

  function getRefund() external checkState(State.Expired) returns (bool){
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


  function changeState(State newState) external onlyOwner{
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