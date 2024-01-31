// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "lib/solbase/src/auth/Owned.sol";

contract MEOWChild is ERC20, Owned {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals,
        address creator
    ) Owned(creator) ERC20(name, symbol, decimals) {
        _mint(creator, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
