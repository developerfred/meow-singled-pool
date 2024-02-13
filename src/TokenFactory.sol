// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {MEOWChild} from "./MEOWChild.sol";
import { LiquidityPool } from "./LiquidityPool.sol";

/// @title TokenFactory for creating MEOWChild tokens and corresponding liquidity pools.
/// @dev Extends Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable for upgradability, ownership management, and reentrancy protection.
contract TokenFactory is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public defaultReserveToken;

    // Array to keep track of all tokens created by this factory.
    address[] public allTokens;
    // Array to keep track of all liquidity pools created by this factory.
    address[] public allPools;

    /// @notice Emitted when a new token is created.
    /// @param tokenAddress The address of the newly created token.
    /// @param creator The address of the token's creator.
    event TokenCreated(address indexed tokenAddress, address indexed creator);

    /// @notice Emitted when a new liquidity pool is created.
    /// @param poolAddress The address of the newly created liquidity pool.
    /// @param tokenAddress The address of the token for which the pool was created.
    /// @param reserveToken The address of the reserve token used in the pool.
    event PoolCreated(address indexed poolAddress, address indexed tokenAddress, address indexed reserveToken);

    /// @notice Initializes the TokenFactory with a specified default reserve token.
    /// @dev Sets the default reserve token used in liquidity pools and initializes inherited contracts.
    /// @param _defaultReserveToken The address of the default reserve token.
    function initialize(address _defaultReserveToken) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        defaultReserveToken = _defaultReserveToken;
    }

    /// @notice Creates a new MEOWChild token and a corresponding liquidity pool.
    /// @dev Deploys a new MEOWChild token and LiquidityPool contract, storing their addresses.
    /// @param name The name of the new token.
    /// @param symbol The symbol of the new token.
    /// @param initialSupply The initial supply of the new token.
    /// @param reserveWeight The reserve weight for the liquidity pool.
    /// @param slope The slope for the liquidity pool pricing curve.
    /// @param creator The address of the token's creator.
    /// @return tokenAddress The address of the newly created token.
    /// @return poolAddress The address of the newly created liquidity pool.
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 reserveWeight,
        uint256 slope,
        address creator
    ) public nonReentrant returns (address tokenAddress, address poolAddress) {
        require(initialSupply > 0, "Initial supply must be > 0");
        require(reserveWeight > 0 && slope > 0, "Invalid reserveWeight or slope");

        MEOWChild newToken = new MEOWChild(name, symbol, initialSupply, creator);
        tokenAddress = address(newToken);
        allTokens.push(tokenAddress);

        LiquidityPool newPool = new LiquidityPool(tokenAddress, defaultReserveToken, reserveWeight, slope);
        poolAddress = address(newPool);
        allPools.push(poolAddress);

        emit TokenCreated(tokenAddress, creator);
        emit PoolCreated(poolAddress, tokenAddress, defaultReserveToken);
    }

    /// @notice Returns the addresses of all tokens created by this factory.
    /// @return An array of addresses of all created tokens.
    function getAllTokens() public view returns (address[] memory) {
        return allTokens;
    }

    /// @notice Returns the addresses of all liquidity pools created by this factory.
    /// @return An array of addresses of all created liquidity pools.
    function getAllPools() public view returns (address[] memory) {
        return allPools;
    }
}