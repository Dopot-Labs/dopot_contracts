// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract Dopot is ERC20, Ownable, ERC20Permit, ERC20Votes  {

    modifier validDestination( address to ) {
        require(to != address(this) );
        _;
    }
   constructor() ERC20("Dopot", "DPT") ERC20Permit("Dopot") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

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