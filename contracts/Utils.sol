// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "./external/Seriality/Seriality.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IPUSHCommInterface {
    function sendNotification(address _channel, address _recipient, bytes calldata _identity) external;
}
interface IDopotReward{ 
    function mintToken(address to, string memory tokenURI, uint256 amount, bytes calldata rewardTier) external returns(uint256);
    function convertToNFT(uint _tokenId, uint _tokenCount) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function whitelistProject(address project) external;
}

contract Utils is Seriality{
    string constant projectUpdateMsg = "Project update";

    enum State {
        PendingApproval,
        Rejected,
        Ongoing,
        Successful,
        Expired,
        Cancelled
    }
    struct AddrParams {
        address fundingTokenAddress;
        address dopotRewardAddress;
        address dptTokenAddress;
        address dptUniPoolAddress;
        address epnsContractAddress;
        address epnsChannelAddress;
    }
    struct ProjectParams {
        uint rewardsLimit;
        uint projectLimit; // max project to create per period
        uint postponeAmount;
        uint postponeFee;
        uint projectWithdrawalFee;
        uint projectDiscountedWithdrawalFee;
        uint postponeThreshold;
        uint period;  // how many blocks before limit resets
    }
    struct RewardTier {
        string ipfshash;
        uint tokenId;
        uint investment;
        uint supply;
        address projectaddress;
        State projectTierState;
    }

    function dptOracleQuote(uint _amount, uint _fee, address _dptTokenAddress, address _dptUniPoolAddress, address _fundingTokenAddress) internal view returns (uint quoteAmount){
        //secondsAgo: 60 * 60 * 24 (24h)
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 60 * 60 * 24;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives,) = IUniswapV3Pool(_dptUniPoolAddress).observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = int24(tickCumulativesDelta / int56(uint56(60 * 60 * 24)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(60 * 60 * 24)) != 0)) tick--;
        quoteAmount = OracleLibrary.getQuoteAtTick(tick, uint128(_amount *  _fee  / 1e18), _fundingTokenAddress, _dptTokenAddress);
    }
    function sendNotif(string memory _title, string memory _body, address _recipient, uint _payloadType, address _epnsContractAddress, address _epnsChannelAddress) internal {
        string memory separator = "+";
        IPUSHCommInterface(_epnsContractAddress).sendNotification(
            _epnsChannelAddress, //set channel via dApp and put it's value -> then once contract is deployed, add contract address as delegate for channel
            _recipient == address(0) ? address(this) : _recipient, // address(this) if Broadcast or Subset. For Targetted put the address to which you want to send
            bytes(
                string(
                    abi.encodePacked(
                        "0", // storage type = minimal
                        separator,
                        _payloadType, // payload type (1, 3 or 4) = (Broadcast, targeted or subset)
                        separator,
                        _title,
                        separator,
                        _body
                    )
                )
            )
        );
    }
    function rewardTierToBytes(RewardTier memory r) pure public returns (bytes memory data) {  
        uint sizeUint = sizeOfUint(256);
        uint sizeOfIpfsHash = sizeOfString(r.ipfshash);
        uint _size = sizeOfIpfsHash + sizeUint + sizeUint + sizeUint + 20 + 6; 
        data = new bytes(32 + _size);
        uint offset = 244;

        stringToBytes(offset, bytes(r.ipfshash), data);
        offset -= sizeOfIpfsHash;
        uintToBytes(offset, r.tokenId, data);
        offset -= sizeUint;
        uintToBytes(offset, r.investment, data);
        offset -= sizeUint;
        uintToBytes(offset, r.supply, data);
        offset -= sizeUint;
        addressToBytes(offset, r.projectaddress, data);
        offset -= 20;
        uintToBytes(offset, uint(r.projectTierState), data);
    }
    function bytesToRewardTier(bytes memory data) pure public returns (RewardTier memory r) {
        uint offset = 244;
        uint sizeUint = sizeOfUint(256);

        r.ipfshash = new string (getStringSize(offset, data));
        bytesToString(offset, data, bytes(r.ipfshash));
        offset -= sizeOfString(r.ipfshash);
        r.tokenId = bytesToUint256(offset, data);
        offset -= sizeUint;
        r.investment = bytesToUint256(offset, data);
        offset -= sizeUint;
        r.supply = bytesToUint256(offset, data);
        offset -= sizeUint;
        r.projectaddress = bytesToAddress(offset, data);
        offset -= 20;
        r.projectTierState = State(bytesToUint256(offset, data));
    }
}