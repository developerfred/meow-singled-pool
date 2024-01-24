// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenFactory {
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public returns (address) {
        MEOWChild newToken = new MEOWChild(name, symbol, initialSupply, msg.sender);
        return address(newToken);
    }
}

contract MEOWChild is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address creator
    ) ERC20(name, symbol) {
        _mint(creator, initialSupply);
    }
}
