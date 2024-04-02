// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { MEOWChild } from "./MEOWChild.sol";

/// @title TokenFactory for creating MEOWChild tokens.
/// @dev Extends Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable for upgradability, ownership management,
/// and reentrancy protection.
contract TokenFactory is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public defaultReserveToken;
    address[] private allTokens;

    struct TokenConfig {
        address tokenAddress;
        address reserveToken;
        uint256 slope;
        uint32 reserveWeight;
    }

    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => address[]) private creatorTokens;
    mapping(address => bool) private isCreatedToken;

    /// @notice Emitted when a new token is created.
    /// @param tokenAddress The address of the newly created token.
    /// @param creator The address of the token's creator.
    event TokenCreated(address indexed tokenAddress, address indexed creator);

    /// @notice Initializes the TokenFactory with a specified default reserve token.
    /// @dev Sets the default reserve token used and initializes inherited contracts.
    /// @param _defaultReserveToken The address of the default reserve token.
    function initialize(address _defaultReserveToken) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        defaultReserveToken = _defaultReserveToken;
    }

    /// @notice Creates a new MEOWChild token and a corresponding
    /// @dev Deploys a new MEOWChild token and LiquidityPool contract, storing their addresses.
    /// @param name The name of the new token.
    /// @param symbol The symbol of the new token.
    /// @param initialSupply The initial supply of the new token.
    /// @param reserveWeight The reserve weight
    /// @param slope The slope for the pricing curve.
    /// @param creator The address of the token's creator.
    /// @return tokenAddress The address of the newly created token.
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint32 reserveWeight,
        uint256 slope,
        address creator,
        address reserveTokenAddress,
        address _exchangeAddress
    )
        external
        nonReentrant
        returns (address tokenAddress)
    {
        require(initialSupply > 0, "Initial supply must be > 0");
        require(reserveWeight > 0 && slope > 0, "Invalid reserveWeight or slope");
        require(_exchangeAddress != address(0), "Exchange address cannot be the zero address");

        address _reserveToken = reserveTokenAddress == address(0) ? defaultReserveToken : reserveTokenAddress;

        MEOWChild newToken = new MEOWChild(name, symbol, initialSupply, creator, _exchangeAddress, _reserveToken);
        tokenAddress = address(newToken);

        tokenConfigs[tokenAddress] = TokenConfig({
            tokenAddress: tokenAddress,
            reserveToken: _reserveToken,
            slope: slope,
            reserveWeight: reserveWeight
        });

        allTokens.push(tokenAddress);
        creatorTokens[creator].push(tokenAddress);
        isCreatedToken[tokenAddress] = true;

        emit TokenCreated(tokenAddress, creator);
    }

    function getTokenConfig(address tokenAddress) external view returns (TokenConfig memory, uint256) {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        uint256 totalSupply = MEOWChild(tokenAddress).totalSupply();
        return (config, totalSupply);
    }

    /**
     * @notice Lists all tokens created by this factory.
     * @return An array of addresses of tokens created by the factory.
     */
    function listAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Retrieves all tokens created by a specific address.
     * @param creator Address of the token creator to filter by.
     * @return An array of addresses of tokens created by the specified creator.
     */
    function tokensCreatedBy(address creator) external view returns (address[] memory) {
        return creatorTokens[creator];
    }

    /**
     * @notice Returns the total number of tokens created by this factory.
     * @return Total number of created tokens.
     */
    function totalCreatedTokens() external view returns (uint256) {
        return allTokens.length;
    }

    /**
     * @notice Checks if the given address is a token created by this factory.
     * @param tokenAddress The address to check.
     * @return True if the address is a token created by the factory, false otherwise.
     */
    function isTokenFromFactory(address tokenAddress) external view returns (bool) {
        return isCreatedToken[tokenAddress];
    }

    /**
     * @notice Retrieves a batch of token addresses created by the factory.
     * @param from Index to start retrieving tokens from.
     * @param to Index to stop retrieving tokens at (exclusive).
     * @return batch An array of token addresses in the specified range.
     */
    function getTokensBatch(uint256 from, uint256 to) external view returns (address[] memory batch) {
        require(to > from, "Invalid range");
        uint256 size = to - from;
        require(size <= allTokens.length, "Range exceeds total tokens count");
        batch = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            batch[i] = allTokens[from + i];
        }
    }
}
