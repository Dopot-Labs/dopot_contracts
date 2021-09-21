// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC20 {
    function balanceOf(address _addr) external view returns (uint256);
}

contract Project is Initializable, AccessControl {
    //bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");: 
    using SafeMath for uint256;
    using SafeMath for uint;
    uint constant private projectWithdrawalFee = 3/100 * (10**18);
    uint constant private projectDiscountedWithdrawalFee = 2/100 * (10**18);

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    address payable public reviewer;
    uint public fundGoalAmount;
    uint public fundRaisingDeadline;
    uint public minimumContribution;
    address private dptTokenContract;
    address private fundingTokenContract;
    mapping (address => uint) public investments;
    enum State {
        PendingApproval,
        Rejected,
        Ongoing,
        Successful,
        Expired
    }
    State public state;
    

    modifier isState(State _state){
        require(state == _state);
        _;
    }

    modifier isCreator() {
        require(hasRole(CREATOR_ROLE, msg.sender));
        _;
    }
    modifier isInvestor() {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
        _;
    }
    modifier isAdmin() {
        require(hasRole(REVIEWER_ROLE, msg.sender));
        _;
    }

    function initialize(address payable _creator, address payable _reviewer, uint _fundRaisingDeadline, uint _fundGoalAmount, uint minimum, address _fundingTokenContract/*, address _dptTokenContract*/) public initializer  {
        fundGoalAmount = _fundGoalAmount;
        fundRaisingDeadline = _fundRaisingDeadline;
        minimumContribution = minimum;
        state = State.PendingApproval;
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
        _setupRole(CREATOR_ROLE, _creator);
        _setupRole(REVIEWER_ROLE, _reviewer);
        reviewer = _reviewer;
    }

    
    function invest() external isInvestor isState(State.Ongoing) payable { //TODO: fundingTokenContract
        require(msg.value >= minimumContribution);
        require(!fundingExpired());
        investments[msg.sender] += msg.value;
    }

    function fundingGoalReached() private view returns (bool) {
        return address(this).balance >= fundGoalAmount;
    }

    function fundingExpired() private returns (bool){
        bool result = block.timestamp > fundRaisingDeadline && state == State.Ongoing;
        if(result) state = State.Expired;
        return result;
    }

    //Get Token balance of Address - to retrieve this contract's stablecoin balance and users' dpt balance
    function balanceOf(address addr, address _tokenContract) public view returns (uint256) {
        IERC20 DPTContract = IERC20(_tokenContract);
        return DPTContract.balanceOf(addr);
    }


    function withdraw() external isCreator { //TODO: fundingTokenContract
        require(fundingExpired(), "Funding not expired");
        require(fundingGoalReached(), "Funding goal not reached");
        uint amount = address(this).balance;
        uint feeAmount = amount * /* (balanceOf(msg.sender, dptTokenContract) > 0 ? projectDiscountedWithdrawalFee : */ projectWithdrawalFee /*)*/ / (10**18);

        (bool successFee,) = reviewer.call{value: feeAmount}("");
        require(successFee, "Failed to send Fee");
        (bool successWithdraw,) = msg.sender.call{value: amount - feeAmount}("");
        require(successWithdraw, "Failed to withdraw");
        state = State.Successful;
    }

    function getRefund() external isInvestor returns (bool){ //TODO: fundingTokenContract
        require(fundingExpired(), "Funding not expired");
        require(!fundingGoalReached(), "Refund not available because funding goal reached");
        require(investments[msg.sender] > 0, "No investments found");
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
}