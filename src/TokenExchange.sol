// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/solady/src/utils/ReentrancyGuard.sol";
import "./TokenFactory.sol";
import { MEOWChild } from "./MEOWChild.sol";
import { PoolMath } from "src/math/PoolMath.sol";
import { SafeTransferLib } from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title TokenExchange
/// @notice This contract allows users to buy and sell tokens in exchange for a specific reserve token.
/// @dev This contract implements reentrancy guard to prevent reentrant calls.
contract TokenExchange is ReentrancyGuard, PoolMath {
    /// @notice Address of the TokenFactory contract.
    TokenFactory public tokenFactory;

    /// @notice Emitted when tokens are bought.
    /// @param buyer The address of the buyer.
    /// @param token The address of the token bought.
    /// @param amountSpent The amount of reserve tokens spent.
    /// @param tokensBought The amount of tokens bought.
    event TokenBought(address indexed buyer, address indexed token, uint256 amountSpent, uint256 tokensBought);

    /// @notice Emitted when tokens are sold.
    /// @param seller The address of the seller.
    /// @param token The address of the token sold.
    /// @param tokensSold The amount of tokens sold.
    /// @param amountReceived The amount of reserve tokens received.
    event TokenSold(address indexed seller, address indexed token, uint256 tokensSold, uint256 amountReceived);

    /// @param _tokenFactory The address of the TokenFactory contract.
    constructor(address _tokenFactory) {
        tokenFactory = TokenFactory(_tokenFactory);
    }

    /// @notice Buys tokens in exchange for reserve tokens.
    /// @dev Fetches token info from the TokenFactory and calculates the number of tokens to buy.
    /// Transfers reserve tokens from the buyer and mints new tokens to the buyer's address.
    /// @param token The address of the token to buy.
    /// @param reserveAmount The amount of reserve tokens to spend.
    function buyToken(address token, uint256 reserveAmount) external nonReentrant {
        IERC20 reserveToken = IERC20(MEOWChild(token).reserveTokenAddress());
        _transferTokensToContract(reserveToken, msg.sender, reserveAmount);
        uint256 currentAllowance = reserveToken.allowance(address(this), token);
        if (currentAllowance < reserveAmount) {
            reserveToken.approve(token, type(uint256).max);
        }
        _exchangeToken(token, reserveAmount, true);
    }

    /// @notice Sells tokens in exchange for reserve tokens.
    /// @dev Fetches token info from the TokenFactory and calculates the number of reserve tokens to receive.
    /// Burns the seller's tokens and transfers reserve tokens to the seller's address.
    /// @param token The address of the token to sell.
    /// @param tokenAmount The amount of tokens to sell.
    function sellToken(address token, uint256 tokenAmount) external nonReentrant {
        _exchangeToken(token, tokenAmount, false);
    }

    /// @dev Internal function to handle both buying and selling of tokens.
    /// @param token The address of the token to buy/sell.
    /// @param amount The amount of tokens or reserve tokens to exchange.
    /// @param isBuying Indicates whether the operation is a buy (true) or sell (false).
    function _exchangeToken(address token, uint256 amount, bool isBuying) internal {
        (TokenFactory.TokenConfig memory config, uint256 totalSupply) = tokenFactory.getTokenConfig(token);

        require(totalSupply > 0, "TokenExchange: Token supply must be positive");
        require(amount > 0, "TokenExchange: Amount must be positive");

        uint256 balanceReserve = IERC20(config.reserveToken).balanceOf(token);
        uint32 reserveWeightDex = config.reserveWeight;
        uint256 resultAmount = calculateExchange(totalSupply, balanceReserve, reserveWeightDex, amount, isBuying);

        require(resultAmount > 0, "TokenExchange: Result amount must be positive");

        if (isBuying) {
            MEOWChild(token).mint(msg.sender, resultAmount);
            MEOWChild(token).depositReserveToken(amount);
            emit TokenBought(msg.sender, token, amount, resultAmount);
        } else {
            MEOWChild(token).burn(msg.sender, amount);
            MEOWChild(token).withdrawReserveToken(msg.sender, resultAmount);
            emit TokenSold(msg.sender, token, amount, resultAmount);
        }
    }

    /// @notice Calculates the amount of tokens that can be bought or sold.
    /// @param token The address of the token to be bought or sold.
    /// @param amount The amount of reserve tokens (for buying) or tokens (for selling).
    /// @param isBuying Indicates whether the operation is a purchase (true) or sale (false) of tokens.
    /// @return calculatedAmount The amount of tokens that can be bought or the amount of reserve tokens
    /// that can be received from the sale.

    function calculateExchangeAmount(
        address token,
        uint256 amount,
        bool isBuying
    )
        external
        view
        returns (uint256 calculatedAmount)
    {
        (TokenFactory.TokenConfig memory config, uint256 totalSupply) = tokenFactory.getTokenConfig(token);
        uint256 supplyAmount = totalSupply;
        address reserveToken = config.reserveToken;
        uint32 reserveWeight = config.reserveWeight;

        uint256 reserveBalance = IERC20(reserveToken).balanceOf(address(token));

        uint256 resultAmount;

        resultAmount = calculateExchange(supplyAmount, reserveBalance, reserveWeight, amount, isBuying);

        return resultAmount;
    }

    function _transferTokensToContract(IERC20 token, address from, uint256 amount) private {
        SafeTransferLib.safeTransferFrom(address(token), from, address(this), amount);
    }

    function _transferTokensFromContract(IERC20 token, address to, uint256 amount) private {
        SafeTransferLib.safeTransfer(address(token), to, amount);
    }
}
