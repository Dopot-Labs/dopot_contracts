// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "hardhat/console.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Project is Initializable, AccessControl, ReentrancyGuard {
    //bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");: 
    using SafeMath for uint256;
    using SafeMath for uint;
    //Needed only to interact with untrusted token contract
    using SafeERC20 for IERC20;
    uint constant public projectWithdrawalFee = 3/100 * 1e18;
    uint constant public projectDiscountedWithdrawalFee = 2/100 * 1e18;

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    address payable public reviewer;
    uint public fundGoalAmount;
    uint public fundRaisingDeadline;
    //address private dptTokenContract;
    address private fundingTokenContract;
    
    enum State {
        PendingApproval,
        Rejected,
        Ongoing,
        Successful,
        Expired,
        Cancelled
    }
    State public state;

    struct rewardTier {
        string name;
        uint investment;
    }
    rewardTier[] public rewardTiers;
    
    mapping (address => mapping (uint256 => uint)) investments;

    modifier isState(State _state){
        require(state == _state);
        _;
    }
    modifier isStateCancellable(){
        require(state == State.PendingApproval || state == State.Ongoing);
        _;
    }
    modifier isRole(bytes32 _role) {
        require(hasRole(_role, msg.sender));
        _;
    }
    modifier isInvestor() {
        require(!hasRole(CREATOR_ROLE, msg.sender) && !hasRole(REVIEWER_ROLE, msg.sender));
        _;
    }

    event Invested(address indexed payee, uint256 tierIndex);
    event ChangedState(State newState);

    function initialize(address payable _creator, address payable _reviewer, uint _fundRaisingDeadline, uint _fundGoalAmount, address _fundingTokenContract/*, address _dptTokenContract*/) public initializer {
        fundGoalAmount = _fundGoalAmount;
        fundRaisingDeadline = _fundRaisingDeadline;
        _changeState(State.PendingApproval);
        //dptTokenContract = _dptTokenContract;
        fundingTokenContract = _fundingTokenContract;
        _setupRole(CREATOR_ROLE, _creator);
        _setupRole(REVIEWER_ROLE, _reviewer);
        reviewer = _reviewer;
    }

    function addRewardTier(string calldata _name, uint _investment) external isRole(CREATOR_ROLE) isState(State.PendingApproval) {
        rewardTiers.push(rewardTier(_name, _investment));
    }

    function fundingGoalReached() private view returns (bool) {
        return address(this).balance >= fundGoalAmount;
    }

    function fundingExpired() private returns (bool){
        bool result = block.timestamp > fundRaisingDeadline && state == State.Ongoing;
        if(result) {
            _changeState(State.Expired);
            emit ChangedState(State.Expired);
        }
        return result;
    }
    
    // User invests in specified reward tier 
    function invest (uint256 tierIndex) external isInvestor isState(State.Ongoing) nonReentrant {
        require(!fundingExpired());
        uint investAmount = rewardTiers[tierIndex].investment;
        uint256 allowance = IERC20(fundingTokenContract).allowance(msg.sender, address(this));
        require(allowance >= investAmount, "Insufficient token allowance");
		IERC20(fundingTokenContract).safeTransferFrom(
			address(msg.sender),
			address(this),
			investAmount
		);
        
        investments[msg.sender][tierIndex] ++; // < remove
        // mint nft

        emit Invested(msg.sender, tierIndex);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw() external isRole(CREATOR_ROLE) nonReentrant {
        require(fundingExpired(), "Funding not expired");
        require(fundingGoalReached(), "Funding goal not reached");
        uint amount = address(this).balance;
        uint feeAmount = amount * /* (IERC20(dptTokenContract).balanceOf(msg.sender, dptTokenContract) > 0 ? projectDiscountedWithdrawalFee : */ projectWithdrawalFee /*)*/ / 1e18;

        IERC20(fundingTokenContract).safeTransfer(reviewer, feeAmount);
        IERC20(fundingTokenContract).safeTransfer(msg.sender, amount - feeAmount);
        _changeState(State.Successful);
        emit ChangedState(State.Successful);
    }

    // Creator or Reviewer cancels pending or ongoing unsuccesful project permitting eventual refunds to investors
    function cancel() external isStateCancellable {
        require(hasRole(REVIEWER_ROLE, msg.sender) || hasRole(CREATOR_ROLE, msg.sender));
        _changeState(State.Cancelled);
    }

    // Investor requests refund for rewards of specified tier
    function refundRewardTier(uint256 tierIndex) external isInvestor nonReentrant {
        require(fundingExpired() || state == State.Cancelled, "Funding not expired or cancelled");
        require(!fundingGoalReached(), "Refund not available because funding goal reached");
        require(investments[msg.sender][tierIndex] > 0, "No investments found in specified tier");
        uint amount = investments[msg.sender][tierIndex] * rewardTiers[tierIndex].investment;
        require(amount > 0);
        IERC20(fundingTokenContract).safeTransfer(msg.sender, amount);
        investments[msg.sender][tierIndex] = 0;
    }

    function changeState(State newState) external isRole(REVIEWER_ROLE) {
        state = newState;
        emit ChangedState(newState);
    }

    function _changeState(State newState) internal {
        state = newState;
        emit ChangedState(newState);
    }
}