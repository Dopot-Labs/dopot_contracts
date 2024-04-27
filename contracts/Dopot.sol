// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC5267.sol";

/// @custom:security-contact info@dopot.fi
contract Dopot is ERC20Permit, ERC20Votes, ERC165, Ownable {

    // Modifier to check if destination address is not this contract
    modifier validDestination( address to ) {
        require(to != address(this) );
        _;
    }

    // Dopot constructor
     constructor()
        ERC20("Dopot", "DPT")
        ERC20Permit("Dopot")
        Ownable()
    {
        _mint(msg.sender, 120000000 * 10 ** decimals());
    }


    // Support for metadata, gas-efficient transfers, voting, multi-interfaces
    function supportsInterface(
        bytes4 _interfaceId
    ) public view virtual override returns (bool) {
        return
            _interfaceId == type(IERC20).interfaceId ||
            _interfaceId == type(IERC20Metadata).interfaceId ||
            _interfaceId == type(IERC5267).interfaceId ||
            _interfaceId == type(IVotes).interfaceId ||
            ERC165.supportsInterface(_interfaceId);
    }


    // The following functions are overrides required by Solidity.

    function transfer(address _to, uint256 _value) public validDestination(_to) override(ERC20) returns (bool)
    {
        super.transfer(_to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public validDestination(_to) override(ERC20) returns (bool)
    {
        super.transferFrom(_from, _to, _value);
        return true;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }
    
    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
