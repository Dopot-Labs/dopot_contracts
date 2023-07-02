// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../Utils.sol";


contract DopotReward is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(address => mapping(string => uint256)) public currentSupplyByProjectAndURI;

    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => Utils.RewardTier) public rewardData;
    mapping (address => bool) projectWhitelist;

    event RewardMinted(address to, uint256 indexed id, Utils.RewardTier);
    event PermanentURI(string _value, uint256 indexed _id);
    constructor(address _projectFactoryContract) ERC1155("ar://{id}") {
        transferOwnership(_projectFactoryContract);
    }

    function whitelistProject(address project) external onlyOwner{
        projectWhitelist[project] = true;
    }

    function mintToken(address to, string memory tokenURI, bytes memory rewardTier) public returns(uint256) { 
        require(projectWhitelist[msg.sender] == true, "Project not whitelisted");
        uint256 newItemId = _tokenIds.current(); 
        mint(to, newItemId, 1, rewardTier);
        _setTokenUri(newItemId, tokenURI);
        currentSupplyByProjectAndURI[msg.sender][tokenURI] ++;
        _tokenIds.increment();

        emit RewardMinted(to, newItemId, Utils.bytesToRewardTier(rewardTier));
        emit PermanentURI(tokenURI, newItemId);
        return newItemId; 
    } 

    function uri(uint256 _tokenID) override public view returns (string memory) {
        return string(
            abi.encodePacked(
            "ar://",
            _tokenURIs[_tokenID])
        );
    }
    function _setTokenUri(uint256 tokenId, string memory tokenURI) private {
         _tokenURIs[tokenId] = tokenURI; 
    }
    
    // The following functions are overrides required by Solidity.
    function mint(address account, uint256 id, uint256 amount, bytes memory data) private {
        Utils.RewardTier memory d = Utils.bytesToRewardTier(data);
        require(currentSupplyByProjectAndURI[msg.sender][_tokenURIs[id]] != d.supply, "Max supply reached");
        d.ipfshash = "";
        d.projectaddress = msg.sender;
        _mint(account, id, amount, "");
        rewardData[id] = d;
    }
    
    function burn(address account, uint256 id,  uint256 value) override(ERC1155Burnable) public {
        require(projectWhitelist[msg.sender] == true || account == _msgSender() || isApprovedForAll(account, msg.sender), "Not approved");
        _burn(account, id, 1);
        currentSupplyByProjectAndURI[msg.sender][_tokenURIs[id]] --;
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        revert("mintBatch function is not available");
    }
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) override(ERC1155Burnable) public {
        revert("burnBatch function is not available");
    }
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function getTotalSupplyByProjectAndTokenURI(address projectAddress, string memory tokenURI) public view returns (uint256) {
        return currentSupplyByProjectAndURI[projectAddress][tokenURI];
    }
}