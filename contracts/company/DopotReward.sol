// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract DopotReward is ERC1155, AccessControl, ERC1155Burnable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    constructor() ERC1155("ipfs://f0{id}") {
        grantRole(MINTER_ROLE, msg.sender);
    }

    /*function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }*/

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyRole(MINTER_ROLE) {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, amounts, data);
    }
    
    function convertToNFT(uint _tokenId) onlyRole(MINTER_ROLE) external {
        //require(_tokenId == PLAYER || _tokenId == COACH || _tokenId == JERSEY || _tokenId == STADIUM, "Invalid Token ID"); BURN TOKEN & MINT NFT
        _mint(msg.sender, _tokenId, 1, "");
    }


    function uri(uint256 _tokenID) override public pure returns (string memory) {
        string memory hexstringtokenID;
        hexstringtokenID = uint2hexstr(_tokenID);
    
        return string(
            abi.encodePacked(
            "ipfs://f0",
            hexstringtokenID)
        );
    }

    function uint2hexstr(uint256 i) public pure returns (string memory) {
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        uint mask = 15;
        bytes memory bstr = new bytes(length);
        uint k = length;
        while (i != 0) {
            uint curr = (i & mask);
            bstr[--k] = curr > 9 ?
                bytes1(uint8(55 + curr)) :
                bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        return string(bstr);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}