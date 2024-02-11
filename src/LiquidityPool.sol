// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./math/PoolMath.sol";
import { ReentrancyGuard } from "lib/solbase/src/utils/ReentrancyGuard.sol";
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

        tokenA.safeTransferFrom(msg.sender, address(this), _tokenAAmount);
        tokenB.safeTransferFrom(msg.sender, address(this), _tokenBAmount);

        reserveA += _tokenAAmount;
        reserveB += _tokenBAmount;

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

        tokenA.safeTransfer(msg.sender, tokenAAmount);
        tokenB.safeTransfer(msg.sender, tokenBAmount);

        reserveA -= tokenAAmount;
        reserveB -= tokenBAmount;

        emit LiquidityRemoved(msg.sender, tokenAAmount, tokenBAmount, _shares);
    }

    /// @notice Swaps tokens using the pool
    /// @dev Calculates the token return amount using the PoolMath library
    /// @param _inputToken Address of the input token
    /// @param _inputAmount Amount of the input token
    function swapTokens(address _inputToken, uint256 _inputAmount) external {
        require(_inputToken == address(tokenA) || _inputToken == address(tokenB), "Invalid input token");
        bool isInputTokenA = _inputToken == address(tokenA);

        uint256 outputAmount;

        if (isInputTokenA) {
            // Swap tokenA to tokenB
            outputAmount = _calculateReturn(_inputAmount, reserveA, reserveB, reserveWeight, true);
            require(tokenB.balanceOf(address(this)) >= outputAmount, "Insufficient liquidity for this trade");
            tokenA.transferFrom(msg.sender, address(this), _inputAmount);
            tokenB.transfer(msg.sender, outputAmount);
            reserveA += _inputAmount;
            reserveB -= outputAmount;
        } else {
            // Swap tokenB to tokenA
            outputAmount = _calculateReturn(_inputAmount, reserveB, reserveA, reserveWeight, true);
            require(tokenA.balanceOf(address(this)) >= outputAmount, "Insufficient liquidity for this trade");
            tokenB.transferFrom(msg.sender, address(this), _inputAmount);
            tokenA.transfer(msg.sender, outputAmount);
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

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _updateReserves(token, amount, otherTokenAmount);

        _mint(msg.sender, sharesToMint);

        // Emite o evento com as quantidades ajustadas
        emit LiquidityAdded(
            msg.sender, token == address(tokenA) ? amount : 0, token == address(tokenB) ? amount : 0, sharesToMint
        );
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
        uint256 totalSupply = totalSupply(); // totalSupply from ERC20 represents the total shares existing
        shares = (totalValueAdded * totalSupply) / totalPoolValue;

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
