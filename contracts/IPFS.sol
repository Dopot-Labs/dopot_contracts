// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./external/Seriality/Seriality.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract IPFS is Seriality{
  error BalanceError();

  enum State {
    PendingApproval,
    Rejected,
    Ongoing,
    Successful,
    Expired,
    Cancelled
  }
  struct AddrParams {
    address payable creator;
    address payable reviewer;
    address fundingTokenAddress;
    address dopotRewardAddress;
    address dptTokenAddress;
    address dptUniPoolAddress;
  }
  struct ProjectParams {
    uint projectWithdrawalFee;
    uint projectDiscountedWithdrawalFee;
    uint postponeFee;
    uint postponeAmount;
    uint postponeThreshold;
    uint projectMediaLimit;
    uint rewardsLimit;
    uint period;  // how many blocks before limit resets
    uint projectLimit; // max project to create per period
  }
  struct RewardTier {
      string ipfshash;
      uint tokenId;
      uint investment;
      uint supply;
      address projectaddress;
      State projectTierState;
  }

  function dptOracleQuote(uint amount, uint fee, AddrParams storage addrParams) internal view returns (uint quoteAmount){
      if(IERC20(addrParams.dptTokenAddress).balanceOf(msg.sender) == 0) revert BalanceError();
      //secondsAgo: 60 * 60 * 24 (24h)
      uint32[] memory secondsAgos = new uint32[](2);
      secondsAgos[0] = 60 * 60 * 24;
      secondsAgos[1] = 0;
      (int56[] memory tickCumulatives,) = IUniswapV3Pool(addrParams.dptUniPoolAddress).observe(secondsAgos);
      int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
      int24 tick = int24(tickCumulativesDelta / int56(uint56(60 * 60 * 24)));
      if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(60 * 60 * 24)) != 0)) tick--;
      quoteAmount = OracleLibrary.getQuoteAtTick(tick, uint128(amount *  fee  / 1e18), addrParams.fundingTokenAddress, addrParams.dptTokenAddress);
  }
  function rewardTierToBytes(RewardTier memory r) pure public returns (bytes memory data) {
        uint _size = sizeOfString(r.ipfshash) + sizeOfUint(256) + sizeOfUint(256) + sizeOfUint(256);
        data = new  bytes(_size);
        uint offset = 256;

        stringToBytes(offset, bytes(r.ipfshash), data);
        offset -= sizeOfString(r.ipfshash);

        uintToBytes(offset, r.tokenId, data);
        offset -= sizeOfUint(256);

        uintToBytes(offset, r.investment, data);
        offset -= sizeOfUint(256);

        uintToBytes(offset, r.supply, data);
        offset -= sizeOfUint(256);
        return (data);
    }
    function bytesToRewardTier(bytes memory data) pure public returns (RewardTier memory r) {
        uint offset = 256;

        bytesToString(offset, data, bytes(r.ipfshash));
        offset -= sizeOfString(r.ipfshash);

        r.tokenId = bytesToUint256(offset, data);
        offset -= sizeOfUint(256);

        r.tokenId = bytesToUint256(offset, data);
        offset -= sizeOfUint(256);
        
        r.tokenId = bytesToUint256(offset, data);
        offset -= sizeOfUint(256);
        return r;
     }
}