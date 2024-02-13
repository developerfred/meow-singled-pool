// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./math/PoolMath.sol";
import { ReentrancyGuard } from "lib/solbase/src/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "lib/solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LiquidityPool for Token Swapping and Liquidity Provision
/// @dev Extends ERC20 to include voting capabilities, utilizes PoolMath for calculating returns, and incorporates
/// ReentrancyGuard for security.
contract LiquidityPool is PoolMath, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 private reserveA;
    uint256 private reserveB;

    uint256 public reserveWeight;
    uint256 public slope;

    /// @notice Emitted when liquidity is added to the pool
    /// @param provider The address of the liquidity provider
    /// @param tokenAAmount The amount of token A added to the pool
    /// @param tokenBAmount The amount of token B added to the pool
    /// @param sharesIssued The amount of liquidity pool shares minted
    event LiquidityAdded(address indexed provider, uint256 tokenAAmount, uint256 tokenBAmount, uint256 sharesIssued);

    /// @notice Emitted when liquidity is removed from the pool
    /// @param provider The address of the liquidity provider
    /// @param tokenAAmount The amount of token A removed from the pool
    /// @param tokenBAmount The amount of token B removed from the pool
    /// @param sharesBurned The amount of liquidity pool shares burned
    event LiquidityRemoved(address indexed provider, uint256 tokenAAmount, uint256 tokenBAmount, uint256 sharesBurned);


    /// @dev Emitted when liquidity is removed from the pool by a single token.
    /// @param provider Address of the liquidity provider removing liquidity.
    /// @param token Address of the token for which liquidity was removed.
    /// @param amount The amount of the token withdrawn from the pool.
    /// @param shares The amount of pool shares burned in the process.
    event LiquiditySingleRemoved(address indexed provider, address indexed token, uint256 amount, uint256 shares);

    
    /// @notice Emitted on token swap
    /// @param trader The address of the trader
    /// @param inputAmount The amount of input token
    /// @param outputAmount The amount of output token received
    /// @param inputToken The input token address
    /// @param outputToken The output token address
    event TokenSwap(
        address indexed trader, uint256 inputAmount, uint256 outputAmount, address inputToken, address outputToken
    );

    constructor(
        address _tokenA,
        address _tokenB,
        uint256 _reserveWeight,
        uint256 _slope
    )
        ERC20("LiquidityPoolShare", "LPS")
        ERC20Permit("LiquidityPoolShare")
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        reserveWeight = _reserveWeight;
        slope = _slope;
    }

    /// @notice Adds liquidity to the pool
    /// @dev Mints pool shares to the liquidity provider based on the current pool ratio
    /// @param _tokenAAmount Amount of token A to add
    /// @param _tokenBAmount Amount of token B to add
    function addLiquidity(uint256 _tokenAAmount, uint256 _tokenBAmount) external nonReentrant {
        uint256 totalLiquidity = reserveA + reserveB;
        uint256 totalSupply = totalSupply();
        uint256 sharesToMint = totalLiquidity == 0
            ? _tokenAAmount + _tokenBAmount
            : (totalSupply * (_tokenAAmount + _tokenBAmount)) / totalLiquidity;

        reserveA += _tokenAAmount;
        reserveB += _tokenBAmount;

        SafeTransferLib.safeTransferFrom(address(tokenA), msg.sender, address(this), _tokenAAmount);
        SafeTransferLib.safeTransferFrom(address(tokenB), msg.sender, address(this), _tokenBAmount);

        _mint(msg.sender, sharesToMint);

        emit LiquidityAdded(msg.sender, _tokenAAmount, _tokenBAmount, sharesToMint);
    }

    /// @notice Removes liquidity from the pool
    /// @dev Burns pool shares and returns proportional amounts of token A and B to the liquidity provider
    /// @param _shares Amount of pool shares to burn
    function removeLiquidity(uint256 _shares) external nonReentrant {
        uint256 totalSupply = totalSupply();
        uint256 tokenAAmount = (reserveA * _shares) / totalSupply;
        uint256 tokenBAmount = (reserveB * _shares) / totalSupply;

        _burn(msg.sender, _shares);

        reserveA -= tokenAAmount;
        reserveB -= tokenBAmount;

        SafeTransferLib.safeTransfer(address(tokenA), msg.sender, tokenAAmount);
        SafeTransferLib.safeTransfer(address(tokenB), msg.sender, tokenBAmount);

        emit LiquidityRemoved(msg.sender, tokenAAmount, tokenBAmount, _shares);
    }

    /// @notice Swaps tokens using the pool
    /// @dev Calculates the token return amount using the PoolMath library
    /// @param _inputToken Address of the input token
    /// @param _inputAmount Amount of the input token
    function swapTokens(address _inputToken, uint256 _inputAmount) external nonReentrant {
        require(_inputToken == address(tokenA) || _inputToken == address(tokenB), "Invalid input token");
        bool isInputTokenA = _inputToken == address(tokenA);

        uint256 outputAmount;

        if (isInputTokenA) {
            // Swap tokenA to tokenB
            outputAmount = _calculateReturn(_inputAmount, reserveA, reserveB, reserveWeight, true);
            require(tokenB.balanceOf(address(this)) >= outputAmount, "Insufficient liquidity for this trade");
            SafeTransferLib.safeTransferFrom(address(tokenA), msg.sender, address(this), _inputAmount);
            SafeTransferLib.safeTransfer(address(tokenB), msg.sender, outputAmount);
            reserveA += _inputAmount;
            reserveB -= outputAmount;
        } else {
            // Swap tokenB to tokenA
            outputAmount = _calculateReturn(_inputAmount, reserveB, reserveA, reserveWeight, true);
            require(tokenA.balanceOf(address(this)) >= outputAmount, "Insufficient liquidity for this trade");
            SafeTransferLib.safeTransferFrom(address(tokenB), msg.sender, address(this), _inputAmount);
            SafeTransferLib.safeTransfer(address(tokenA), msg.sender, outputAmount);
            reserveB += _inputAmount;   
            reserveA -= outputAmount;
        }

        emit TokenSwap(
            msg.sender, _inputAmount, outputAmount, _inputToken, isInputTokenA ? address(tokenB) : address(tokenA)
        );
    }

    function addSingleSidedLiquidity(address token, uint256 amount) external nonReentrant {
        require(token == address(tokenA) || token == address(tokenB), "Invalid token address");

        uint256 affectedReserve = token == address(tokenA) ? reserveA : reserveB;
        uint256 otherReserve = token == address(tokenA) ? reserveB : reserveA;

        uint256 otherTokenAmount = _calculateEquivalent(token, amount);
        require(otherTokenAmount <= otherReserve, "Insufficient reserve for the other token");

        uint256 sharesToMint = _calculateShares(amount, otherTokenAmount, affectedReserve, otherReserve);
        SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), amount);

        _updateReserves(token, amount, otherTokenAmount);

        _mint(msg.sender, sharesToMint);

        // Emite o evento com as quantidades ajustadas
        emit LiquidityAdded(
            msg.sender, token == address(tokenA) ? amount : 0, token == address(tokenB) ? amount : 0, sharesToMint
        );
    }



    /// @notice Removes liquidity from the pool for a single token, identified by its address.
    /// @dev Burns pool shares and returns a proportional amount of the specified token to the liquidity provider.
    /// @param token The address of the token to remove liquidity for.
    /// @param shares The amount of pool shares to burn for removing liquidity.
    function removeSingleSidedLiquidity(address token, uint256 shares) external nonReentrant {
        require(token == address(tokenA) || token == address(tokenB), "Invalid token address");


        require(totalSupply() > 0, "No liquidity in pool");
        
        // Calculates the user's share of the token reserve based on the pool's total supply.
        uint256 tokenReserve = token == address(tokenA) ? reserveA : reserveB;
        uint256 amountToWithdraw = (tokenReserve * shares) / totalSupply();

        // Ensures the user has enough shares to perform the withdrawal.
        require(balanceOf(msg.sender) >= shares, "Not enough shares");

        // Burns the user's shares.
        _burn(msg.sender, shares);

        // Updates the pool's reserves.
        if (token == address(tokenA)) {
            reserveA -= amountToWithdraw;
        } else {
            reserveB -= amountToWithdraw;
        }

        // Transfers the specified token back to the user.
        SafeTransferLib.safeTransfer(address(token), msg.sender, amountToWithdraw);

        // Emits an event with the adjusted amounts.
        emit LiquiditySingleRemoved(msg.sender, token, amountToWithdraw, shares);
    }

    function _calculateEquivalent(address token, uint256 amount) private view returns (uint256) {
        require(token == address(tokenA) || token == address(tokenB), "Invalid token address");

        if (reserveA == 0 || reserveB == 0) {
            return amount;
        }

        uint256 equivalentAmount;
        if (token == address(tokenA)) {
            equivalentAmount = (amount * reserveB) / reserveA;
        } else {
            equivalentAmount = (amount * reserveA) / reserveB;
        }

        return equivalentAmount;
    }

    function _calculateShares(
        uint256 amount,
        uint256 otherTokenAmount,
        uint256 affectedReserve,
        uint256 otherReserve
    )
        private
        view
        returns (uint256 shares)
    {
        // Calculate the total value added to the pool
        uint256 totalValueAdded = amount + otherTokenAmount;

        // Calculate the total current value in the pool
        uint256 totalPoolValue = affectedReserve + otherReserve;

        // If the pool is empty, initialize it with a direct 1:1 ratio
        if (totalPoolValue == 0) {
            return totalValueAdded;
        }

        // Calculate the proportion of new liquidity to the total pool value
         // totalSupply from ERC20 represents the total shares existing
        shares = (totalValueAdded * totalSupply()) / totalPoolValue;

        return shares;
    }

    function _updateReserves(address token, uint256 amount, uint256 otherTokenAmount) private {
        if (token == address(tokenA)) {
            reserveA += amount;
            reserveB -= otherTokenAmount;
        } else {
            reserveB += amount;
            reserveA -= otherTokenAmount;
        }
    }
    
}
