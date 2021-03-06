// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../IPFS.sol";


contract DopotReward is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply, IPFS {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => bool) public isNFT;
    mapping (uint256 => IPFS.RewardTier) public rewardData;
    mapping(uint256 => mapping(address => bytes)) public shippingData;
    mapping (address => bool) projectWhitelist;

    event RewardMinted(address to, uint256 id, uint256 amount, IPFS.RewardTier);
    event RewardDelivered(uint256 indexed tokenId, address indexed buyer, uint256 tokenCount);
    error WhitelistError();
    error ApprovalError();
    error NFTError();
    constructor(address _projectFactoryContract) ERC1155("ipfs://{id}") {
        transferOwnership(_projectFactoryContract);
    }

    function whitelistProject(address project) external onlyOwner{
        projectWhitelist[project] = true;
    }
    function onlyWhitelistedProject() private view{
        if(projectWhitelist[msg.sender] == false) revert WhitelistError();
    }

    function editShippingDetails(uint id, bytes calldata shippingDetails) external {
        require(balanceOf(msg.sender, id) > 0, "Not owner");
        shippingData[id][msg.sender] = shippingDetails;
    }

    function mintToken(address to, string memory tokenURI, uint amount, bytes memory rewardTier) public returns(uint256) { 
        onlyWhitelistedProject();
        uint newItemId = _tokenIds.current(); 
        mint(msg.sender, newItemId, amount, rewardTier);
        _setTokenUri(newItemId, tokenURI);
        _tokenIds.increment();

        emit RewardMinted(to, newItemId, amount, IPFS.bytesToRewardTier(rewardTier));
        return newItemId; 
    } 

    function convertToNFT(uint _tokenId, uint _tokenCount) external {
        onlyWhitelistedProject();
        require(rewardData[_tokenId].projectaddress == msg.sender, "Not minter");
        isNFT[_tokenId] = true;
        emit RewardDelivered(_tokenId, msg.sender, _tokenCount);
    }

    function uri(uint256 _tokenID) override public view returns (string memory) {
        return string(
            abi.encodePacked(
            "ipfs://",
            _tokenURIs[_tokenID])
        );
    }
    function _setTokenUri(uint256 tokenId, string memory tokenURI)  private {
         _tokenURIs[tokenId] = tokenURI; 
    }
    
    // The following functions are overrides required by Solidity.
    function mint(address account, uint256 id, uint256 amount, bytes memory data) private {
        IPFS.RewardTier memory d = IPFS.bytesToRewardTier(data);
        d.ipfshash = "";
        d.projectaddress = msg.sender;
        _mint(account, id, amount, "");
        rewardData[id] = d;
    }
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
    function burn(address account, uint256 id, uint256 value) override(ERC1155Burnable) public {
        if(account != _msgSender() && !isApprovedForAll(account, _msgSender())) revert ApprovalError();
        if(isNFT[id] == false) revert NFTError();
        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) override(ERC1155Burnable) public {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");
        for (uint i=0; i < ids.length; i += 1) {
            if(isNFT[ids[i]] == false) revert NFTError();
        }
        _burnBatch(account, ids, values);
    }
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}