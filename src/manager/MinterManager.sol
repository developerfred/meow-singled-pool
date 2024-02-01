// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../MEOWChild.sol";
import "lib/solbase/src/auth/Owned.sol";

contract MinterManager is Owned {
    address public tokenFactory;

    constructor(address _tokenFactory) Owned(msg.sender) {
        tokenFactory = _tokenFactory;
    }

    // Mapeia um contrato MEOWChild para seu LiquidityPool autorizado
    mapping(address => address) public authorizedPools;

    event PoolAuthorized(address indexed meowChild, address indexed pool);
    event Minted(address indexed meowChild, address indexed to, uint256 amount);
    event Burned(address indexed meowChild, address indexed to, uint256 amount);

    modifier onlyAuthorized(address meowChild) {
        require(authorizedPools[meowChild] != address(0), "MEOWChild not authorized");
        _;
    }

    modifier onlyOwnerOrTokenFactory() {
        require(msg.sender == owner || msg.sender == tokenFactory, "Not authorized");
        _;
    }

    function authorizePool(address meowChild, address pool) external onlyOwnerOrTokenFactory {
        authorizedPools[meowChild] = pool;
        emit PoolAuthorized(meowChild, pool);
    }

    function mint(address meowChild, address to, uint256 amount) external onlyAuthorized(meowChild) {
        MEOWChild(meowChild).mint(to, amount);
        emit Minted(meowChild, to, amount);
    }

    function burn(address meowChild, address to, uint256 amount) external onlyAuthorized(meowChild) {
        MEOWChild(meowChild).burn(to, amount);
        emit Burned(meowChild, to, amount);
    }

    function setTokenFactory(address _tokenFactory) external onlyOwner {
        tokenFactory = _tokenFactory;
    }
}