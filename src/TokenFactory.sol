// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {MEOWChild} from "./MEOWChild.sol";

/// @title TokenFactory for creating MEOWChild tokens and corresponding liquidity pools.
/// @dev Extends Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable for upgradability, ownership management, and reentrancy protection.
contract TokenFactory is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public defaultReserveToken;
    address public immutable exchangeAddress;

    struct TokenConfig {
        address tokenAddress;
        address reserveToken;
        uint256 slope;
        uint256 reserveWeight;
    }

    mapping(address => TokenConfig) public tokenConfigs;

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
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 reserveWeight,
        uint256 slope,
        address creator,
        address reserveTokenAddress
    ) public nonReentrant returns (address tokenAddress) {
        require(initialSupply > 0, "Initial supply must be > 0");
        require(reserveWeight > 0 && slope > 0, "Invalid reserveWeight or slope");

        address _reserveToken = reserveTokenAddress == address(0) ? defaultReserveToken : reserveTokenAddress;
        
        MEOWChild newToken = new MEOWChild(name, symbol, initialSupply, creator, exchangeAddress);
        tokenAddress = address(newToken);

        tokenConfigs[tokenAddress] = TokenConfig({
            tokenAddress: tokenAddress,
            reserveToken: _reserveToken,
            slope: slope,
            reserveWeight: reserveWeight
        });

        emit TokenCreated(tokenAddress, creator);
    }

    function getTokenConfig(address tokenAddress) external view returns (TokenConfig memory, uint256) {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        uint256 totalSupply = MEOWChild(tokenAddress).totalSupply();
        return (config, totalSupply);
    }
}