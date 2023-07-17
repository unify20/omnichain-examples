// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/MORC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MORC20MintablepausableToken is ERC20Burnable, MORC20Pausable {

    constructor(
        string memory _name,
        string memory _symbol,
        address _mosAddress,
        uint256 _initialSupply,
        address _owner
    )
    MORC20Pausable(_name, _symbol,_mosAddress)
    {
        _transferOwnership(_owner);
        _mint(_owner,_initialSupply);
    }

    function mint(address _receiveAddress,uint256 _amount) public virtual onlyOwner{
        _mint(_receiveAddress,_amount);
    }

}
