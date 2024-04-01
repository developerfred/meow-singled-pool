// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ABDKMathQuad.sol";

abstract contract PoolMath {
    using ABDKMathQuad for bytes16;
    uint32 private constant MAX_WEIGHT = 1000000;
    bytes16 private constant ONE = 0x3fff0000000000000000000000000000;

    function calculateExchange(
        uint256 tokenSupply,
        uint256 reserveBalance,
        uint32 reserveWeight,
        uint256 amount,
        bool isBuying
    ) internal pure returns (uint256) {
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

    function _calculatePurchaseReturn(
    bytes16 supply,
    bytes16 balance,
    bytes16 weight,
    bytes16 amt
) private pure returns (bytes16) {
    // Caso especial para depósito de 0
    if (amt == 0) {
        return 0;
    }
    // Caso especial se o peso é 100%
    if (weight == ONE) {
        return amt.mul(supply).div(balance);
    }

    bytes16 part1 = amt.div(balance).add(ONE);
    bytes16 part2 = part1.ln().mul(weight).exp();

    return supply.mul(part2.sub(ONE));
}


    function _calculateSaleReturn(
    bytes16 supply,
    bytes16 balance,
    bytes16 weight,
    bytes16 amt
) private pure returns (bytes16) {
    // Caso especial para a venda de 0 tokens
    if (amt == 0) {
        return 0;
    }
    // Caso especial para venda do suprimento total
    if (amt == supply) {
        return balance;
    }
    // Caso especial se o peso é 100%
    if (weight == ONE) {
        return amt.mul(balance).div(supply);
    }

    bytes16 part1 = ONE.sub(amt.div(supply));
    bytes16 part2 = ONE.div(weight).exp().sub(part1.ln().mul(ONE.div(weight)).exp());

    return balance.mul(part2);
}

}
