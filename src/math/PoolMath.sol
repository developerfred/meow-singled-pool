
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import  "lib/prb-math/src/UD60x18.sol";

abstract contract PoolMath {

    /// @notice Calculates the return amount for a given operation in a liquidity pool.
    /// @dev Performs fixed-point arithmetic to calculate either purchase or sale returns in a pool.
    /// Uses UD60x18 library for high precision mathematical operations.
    /// @param amount The amount of tokens being bought or sold.
    /// @param supplyAmount The total supply of the pool tokens.
    /// @param reserveAmount The reserve amount of the asset in the pool.
    /// @param reserveWeight The weight of the reserve in the pool, represented in parts per million.
    /// @param isPurchase A boolean indicating the direction of the operation: true for purchase, false for sale.
    /// @return The calculated return amount in the transaction, after applying the pool's pricing formula.
    function _calculateReturn(
        uint256 amount,
        uint256 supplyAmount,
        uint256 reserveAmount,
        uint256 reserveWeight,
        bool isPurchase
    ) internal pure returns (uint256) {
        UD60x18 weightRatio = ud(reserveWeight).div(ud(1000000));
        UD60x18 result;

        if (isPurchase) {
            result = ud(amount)
                .mul(ud(supplyAmount))
                .div(ud(reserveAmount).mul(weightRatio));
        } else {
            result = ud(amount)
                .mul(ud(reserveAmount))
                .div(ud(supplyAmount).mul(weightRatio));
        }

        return convert(result);
    }
}
