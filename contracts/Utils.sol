// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "./external/Seriality/BytesToTypes.sol";
import "./external/Seriality/TypesToBytes.sol";
import "./external/Seriality/SizeOf.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

library Utils{
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
        address creator;
        address reviewer;
    }
    struct ProjectParams {
        uint256 goal;
        uint256 rewardsLimit;
        uint256 projectLimit; // max project to create per period
        uint256 postponeAmount;
        uint256 postponeFee;
        uint256 projectWithdrawalFee;
        uint256 projectStakingReward;
        uint256 insurance;
        uint256 postponeThreshold;
        uint256 period;  // how many blocks before limit resets
    }
    struct RewardTier {
        string hash;
        uint256 investment;
        uint256 supply;
        address projectaddress;
    }
    
    function rewardTierToBytes(RewardTier memory r) pure public returns (bytes memory data) {  
        uint256 sizeUint = SizeOf.sizeOfUint(256);
        uint256 sizeOfHash = SizeOf.sizeOfString(r.hash);
        uint256 _size = sizeOfHash + sizeUint + sizeUint + sizeUint + 20 + 6; 
        data = new bytes(32 + _size);
        uint256 offset = 244;

        TypesToBytes.stringToBytes(offset, bytes(r.hash), data);
        offset -= sizeOfHash;
        TypesToBytes.uintToBytes(offset, r.investment, data);
        offset -= sizeUint;
        TypesToBytes.uintToBytes(offset, r.supply, data);
        offset -= sizeUint;
        TypesToBytes.addressToBytes(offset, r.projectaddress, data);
        offset -= 20;
    }
    function bytesToRewardTier(bytes memory data) pure public returns (RewardTier memory r) {
        uint256 offset = 244;
        uint256 sizeUint = SizeOf.sizeOfUint(256);

        r.hash = new string (BytesToTypes.getStringSize(offset, data));
        BytesToTypes.bytesToString(offset, data, bytes(r.hash));
        offset -= SizeOf.sizeOfString(r.hash);
        r.investment = BytesToTypes.bytesToUint256(offset, data);
        offset -= sizeUint;
        r.supply = BytesToTypes.bytesToUint256(offset, data);
        offset -= sizeUint;
        r.projectaddress = BytesToTypes.bytesToAddress(offset, data);
        offset -= 20;
    }
    function isDeadlineRange(uint256 _deadline) pure internal returns(bool){
        return (_deadline == 45 days || _deadline == 65 days || _deadline == 90 days);
    }

    uint256 constant oracleDecimals = 1e18;
     function estimateAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool,
        uint32 secondsAgo
    ) public view returns (uint256) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(
            secondsAgos
        );
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));
        if (
            tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(secondsAgo) != 0)
        ) {
            tick--;
        }
        uint256 amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(amountIn / oracleDecimals),
            tokenIn,
            tokenOut
        );
        amountOut *= oracleDecimals;
        return amountOut;
    }
}