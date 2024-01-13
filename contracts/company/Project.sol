// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
interface IProjectFactory {
    function emitProjectRewardTierAdded(string calldata _hash) external;
    function emitProjectInvested(address investor, uint tokenId) external;
    function emitProjectRefunded(address investor, uint tokenId) external;
    function sendNotif(string memory _title, string memory _body, address _recipient, uint256 _payloadType) external;
    function emitChangedState(Utils.State newState) external;
}

interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, bytes calldata rewardTier) external returns(uint256);
    function burn(address account, uint256 id, uint256 value) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function whitelistProject(address project) external;
    function getRewardData(uint256 id) external view returns (Utils.RewardTier memory);
}

contract Project is Initializable, Ownable, ReentrancyGuard {
    IDopotReward dopotRewardContract;
    IERC20 fundingTokenContract;
    using SafeERC20 for IERC20;
    uint256 public fundRaisingDeadline;
    address addrProjectFactory;
    Utils.AddrParams public addrParams;
    Utils.ProjectParams public projectParams;
    Utils.RewardTier[] public rewardTiers;
    bool public paused;
    Utils.State public state;
    mapping(address => uint) public stakes;
    uint public totalStaked;

    function isState(Utils.State _state) internal view {
        require(state == _state, "Incorrect State");
    }

    function dptAddressesSet() internal view returns (bool) {
        return (addrParams.dptTokenAddress != address(0x0) && addrParams.dptUniPoolAddress != address(0x0));
    }
   
    function stake(uint amount) external nonReentrant {
        require(dptAddressesSet(), "Dpt addresses not set");
        require(amount > 0, "Must stake above 0");
        isState(Utils.State.Ongoing);
        require(!paused && !fundingExpired(), "Paused or expired");
        require(fundingTokenContract.balanceOf(address(this)) < projectParams.goal, "Goal already reached");
        IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;
        totalStaked += amount;
    }

    function unstake() external nonReentrant {
        require(dptAddressesSet(), "Dpt addresses not set");
        require(stakes[msg.sender] > 0, "No stake");
        require(!paused && (state == Utils.State.Successful || state == Utils.State.Cancelled || fundingExpired()), "Paused or ongoing");
        uint stakeAmount = stakes[msg.sender];
        if(state == Utils.State.Successful && msg.sender != addrParams.creator){
            uint256 dptBalance = IERC20(addrParams.dptTokenAddress).balanceOf(address(this)); //Includes staking rewards
            uint256 creatorStake = stakes[addrParams.creator];
            //User's staking reward
            stakeAmount += stakeAmount * ((dptBalance - creatorStake) / (totalStaked - creatorStake));
        }
        stakes[msg.sender] = 0;
        IERC20(addrParams.dptTokenAddress).safeTransferFrom(address(this), msg.sender, stakeAmount);
        totalStaked -= stakeAmount;
    }

    function getTiersLength() external view returns (uint256) {
        return rewardTiers.length;
    }

    modifier onlyRole(address _addr){
        require(msg.sender == _addr, "Wrong role");
        _;
    }

    function togglePause() external onlyRole(addrParams.reviewer) {
        paused = !paused;
    }
    
    function isInvestor() internal view {
        require(addrParams.creator != msg.sender && addrParams.reviewer != msg.sender, "Creator or reviewer");
    }

    function initialize(address _creator, Utils.AddrParams calldata _addrParams, uint256 _fundRaisingDeadline, Utils.ProjectParams memory _projectParams) external initializer nonReentrant {
        dopotRewardContract = IDopotReward(_addrParams.dopotRewardAddress);
        fundingTokenContract = IERC20(_addrParams.fundingTokenAddress);
        addrProjectFactory = msg.sender;
        addrParams = _addrParams;
        addrParams.creator = _creator;
        fundRaisingDeadline = _fundRaisingDeadline;
        projectParams = _projectParams;
    }

    function isHashUnique(string memory hash) public view returns (bool) {
        for (uint256 i = 0; i < rewardTiers.length; i++) {
            if (keccak256(abi.encodePacked(rewardTiers[i].hash)) == keccak256(abi.encodePacked(hash))) {
                return false;
            }
        }
        return true;
    }

    function addRewardTier(string memory _hash, uint256 _investment, uint256 _supply) external onlyRole(addrParams.creator) nonReentrant {
        require(!paused && rewardTiers.length < projectParams.rewardsLimit && isHashUnique(_hash));
        rewardTiers.push(Utils.RewardTier(_hash, _investment, _supply, address(0)));
        IProjectFactory(addrProjectFactory).emitProjectRewardTierAdded(_hash);
    }

    function fundingExpired() internal returns (bool){
        uint256 deadline = fundRaisingDeadline;
        if(Utils.isDeadlineRange(deadline)) return false;
        if((block.timestamp > deadline) && state == Utils.State.Ongoing) {
            state = Utils.State.Expired;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Tier deadline reached", addrParams.creator, 3);
            IProjectFactory(addrProjectFactory).emitChangedState(Utils.State.Expired);
        }
        return (block.timestamp > deadline);
    }
    // Creator pays to postpone deadline
    function postponeDeadline() external onlyRole(addrParams.creator) nonReentrant{
        isState(Utils.State.Ongoing);
        address _dptTokenAddress = addrParams.dptTokenAddress;
        uint256 fundingTokenBalance = fundingTokenContract.balanceOf(address(this));
        require(!paused && fundingTokenBalance >= (projectParams.goal  *  projectParams.postponeThreshold / 1e18));
        if(dptAddressesSet())
            IERC20(_dptTokenAddress).safeTransferFrom(msg.sender, addrParams.reviewer, Utils.dptOracleQuote(projectParams.goal - fundingTokenBalance, projectParams.postponeFee, _dptTokenAddress, addrParams.dptUniPoolAddress, addrParams.fundingTokenAddress));
        fundRaisingDeadline += projectParams.postponeAmount;
    }

    // User invests in specified reward tier
    function invest (uint256 tierIndex) external {
        isInvestor();
        isState(Utils.State.Ongoing);
        require(!paused && !fundingExpired(), "Paused or expired");
        Utils.RewardTier memory r = rewardTiers[tierIndex];
		fundingTokenContract.safeTransferFrom(msg.sender, address(this), rewardTiers[tierIndex].investment);
        uint tokenId = dopotRewardContract.mintToken(msg.sender, r.hash, Utils.rewardTierToBytes(r));
        rewardTiers[tierIndex] = r;
        IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Someone invested in your project", addrParams.creator, 3);
        IProjectFactory(addrProjectFactory).emitProjectInvested(msg.sender, tokenId);
    }

    // Creator withdraws succesful project funds to wallet
    function withdraw() external onlyRole(addrParams.creator) nonReentrant{
        address _fundToken = addrParams.fundingTokenAddress;
        IERC20 _fundingTokenContract = fundingTokenContract;
        uint256 balance = _fundingTokenContract.balanceOf(address(this));
        require(!paused && balance >= projectParams.goal);
        uint256 insuranceAmount = balance * projectParams.insurance / 1e18;
        if(dptAddressesSet()){
            uint256 feeDptAmount = Utils.dptOracleQuote(balance, projectParams.projectWithdrawalFee, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken);
            //Use creator's staked dpt first to pay for fees
            uint256 creatorStake = stakes[addrParams.creator];
            if(creatorStake > 0){
                if(creatorStake >= feeDptAmount){
                    stakes[addrParams.creator] -= feeDptAmount;
                    totalStaked -= feeDptAmount;
                    IERC20(addrParams.dptTokenAddress).safeTransferFrom(address(this), addrParams.reviewer, feeDptAmount);
                } else {
                    uint256 dptShortage =  feeDptAmount - creatorStake;
                    stakes[addrParams.creator] -= creatorStake;
                    totalStaked -= creatorStake;
                    IERC20(addrParams.dptTokenAddress).safeTransferFrom(address(this), addrParams.reviewer, creatorStake);
                    IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, addrParams.reviewer, dptShortage);
                }
            } else {
                IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, addrParams.reviewer, feeDptAmount);
            }

            creatorStake = stakes[addrParams.creator];
            uint256 stakingRewardAmount = Utils.dptOracleQuote(balance, projectParams.projectStakingReward, addrParams.dptTokenAddress, addrParams.dptUniPoolAddress, _fundToken);
            //If any remaining dpt staked "pay" the staking reward with them
            if(creatorStake > 0){
                if(creatorStake >= stakingRewardAmount){
                    stakes[addrParams.creator] -= stakingRewardAmount;
                    totalStaked -= stakingRewardAmount;
                    //No need to transfer
                } else {
                    uint256 dptShortage =  stakingRewardAmount - creatorStake;
                    stakes[addrParams.creator] -= creatorStake;
                    totalStaked -= creatorStake;
                    IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, address(this), dptShortage);
                }
            } else {
                IERC20(addrParams.dptTokenAddress).safeTransferFrom(msg.sender, address(this), stakingRewardAmount);
            }
        }
        //Project's funds
        _fundingTokenContract.safeTransfer(msg.sender, balance - insuranceAmount);
        //Insurance
        _fundingTokenContract.safeTransfer(addrProjectFactory, insuranceAmount);
        state = Utils.State.Successful;
        IProjectFactory(addrProjectFactory).emitChangedState(state);
    }

    // Investor requests refund for specified reward
    function refund(uint256 tokenId) external {
        isInvestor();
        require(!paused && (fundingExpired() || state == Utils.State.Ongoing || state == Utils.State.Cancelled), "Paused/Successful");
        dopotRewardContract.burn(msg.sender, tokenId, 1);
        IERC20(addrParams.fundingTokenAddress).safeTransfer(msg.sender, dopotRewardContract.getRewardData(tokenId).investment);
        IProjectFactory(addrProjectFactory).emitProjectRefunded(msg.sender, tokenId);
    }

    function changeState(Utils.State newState) public onlyRole(addrParams.reviewer) {
        state = newState;
        if((newState == Utils.State.Ongoing) ) {
            require(Utils.isDeadlineRange(fundRaisingDeadline), "Invalid deadline");
            fundRaisingDeadline += block.timestamp;
            IProjectFactory(addrProjectFactory).sendNotif(Utils.projectUpdateMsg, "Now ongoing", addrParams.creator, 3);
        }
        IProjectFactory(addrProjectFactory).emitChangedState(newState);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

