// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "lib/solbase/src/auth/Owned.sol";

contract ReserveTokenMock is ERC20, Owned {
    constructor(string memory name, string memory symbol) Owned(msg.sender) ERC20(name, symbol, 18) {
        _mint(msg.sender, 1000000 * 10**18); 
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
