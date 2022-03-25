// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
/**
 * @title IPFSStorage
 * @author Forest Fang (@saurfang)
 * @dev Stores IPFS (multihash) hash by address. A multihash entry is in the format
 * of <varint hash function code><varint digest size in bytes><hash function output>
 * See https://github.com/multiformats/multihash
 *
 * Currently IPFS hash is 34 bytes long with first two segments represented as a single byte (uint8)
 * The digest is 32 bytes long and can be stored using bytes32 efficiently.
 */
library IPFS {
  struct Multihash {
    bytes32 digest;
    uint8 hashFunction;
    uint8 size;
  }

  struct RewardTier {
      bytes32 digest;
      uint8 hashFunction;
      uint8 size;
      
      uint investment;
      uint supply;
  }
}