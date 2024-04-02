// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ABDKMathQuad.sol";

/// @title PoolMath: A contract for calculating token exchange amounts in a liquidity pool.
/// @dev This contract uses ABDKMathQuad for high-precision math operations.
/// @notice The calculations assume a constant product formula with weighted reserves.
abstract contract PoolMath {
    using ABDKMathQuad for bytes16;

    uint32 private constant MAX_WEIGHT = 1_000_000; // The maximum weight value, used for normalization.
    bytes16 private constant ONE = 0x3fff0000000000000000000000000000; // Representation of 1 in ABDKMathQuad format.

    /// @notice Calculates the token amount for a purchase or sale operation in the pool.
    /// @param tokenSupply The total supply of the pool tokens.
    /// @param reserveBalance The current balance of the reserve token in the pool.
    /// @param reserveWeight The weight of the reserve token.
    /// @param amount The amount of tokens being bought or sold.
    /// @param isBuying Indicates whether the operation is a purchase (true) or sale (false).
    /// @return The amount of tokens to be received or given in the operation.
    function calculateExchange(
        uint256 tokenSupply,
        uint256 reserveBalance,
        uint32 reserveWeight,
        uint256 amount,
        bool isBuying
    )
        internal
        pure
        returns (uint256)
    {
        bytes16 supply = ABDKMathQuad.fromUInt(tokenSupply);
        bytes16 balance = ABDKMathQuad.fromUInt(reserveBalance);
        bytes16 weight = ABDKMathQuad.fromUInt(reserveWeight).div(ABDKMathQuad.fromUInt(MAX_WEIGHT));
        bytes16 amt = ABDKMathQuad.fromUInt(amount);

        if (isBuying) {
            return _calculatePurchaseReturn(supply, balance, weight, amt).toUInt();
        } else {
            return _calculateSaleReturn(supply, balance, weight, amt).toUInt();
        }
    }

    /// @dev Calculates the return for a token purchase.
    /// @param supply The total supply of the pool tokens in ABDKMathQuad format.
    /// @param balance The balance of the reserve token in ABDKMathQuad format.
    /// @param weight The weight of the reserve token, normalized.
    /// @param amt The amount of tokens being bought, in ABDKMathQuad format.
    /// @return The amount of pool tokens to be received.
    function _calculatePurchaseReturn(
        bytes16 supply,
        bytes16 balance,
        bytes16 weight,
        bytes16 amt
    )
        private
        pure
        returns (bytes16)
    {
        if (amt == 0) {
            return 0;
        }
        if (weight == ONE) {
            return amt.mul(supply).div(balance);
        }

        bytes16 part1 = amt.div(balance).add(ONE);
        bytes16 part2 = part1.ln().mul(weight).exp();

        return supply.mul(part2.sub(ONE));
    }

    /// @dev Calculates the return for selling tokens.
    /// @param supply The total supply of the pool tokens in ABDKMathQuad format.
    /// @param balance The balance of the reserve token in ABDKMathQuad format.
    /// @param weight The weight of the reserve token, normalized.
    /// @param amt The amount of tokens being sold, in ABDKMathQuad format.
    /// @return The amount of reserve tokens to be received.
    function _calculateSaleReturn(
        bytes16 supply,
        bytes16 balance,
        bytes16 weight,
        bytes16 amt
    )
        private
        pure
        returns (bytes16)
    {
        if (amt == 0) {
            return 0;
        }
        if (amt == supply) {
            return balance;
        }
        if (weight == ONE) {
            return amt.mul(balance).div(supply);
        }

        bytes16 part1 = ONE.sub(amt.div(supply));
        bytes16 part2 = ONE.div(weight).exp().sub(part1.ln().mul(ONE.div(weight)).exp());

        return balance.mul(part2);
    }
}
