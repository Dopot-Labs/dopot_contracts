// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./external/Seriality/Seriality.sol";

contract IPFS is Seriality{
  struct RewardTier {
      string ipfshash;
      uint256 tokenId;
      uint256 investment;
      uint256 supply;
  }
  function rewardTierToBytes(RewardTier calldata r) pure public returns (bytes memory data) {
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
    function bytesToRewardTier(bytes calldata data) pure public returns (RewardTier memory r) {
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