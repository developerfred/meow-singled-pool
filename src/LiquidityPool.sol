// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityPoolToken is ERC20Burnable, Ownable {
    using SafeMath for uint256;

    constructor() ERC20("LiquidityProviderToken", "LPT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract LiquidityPool is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    IERC20 public token;
    LiquidityPoolToken public lpToken;

    uint256 public constant reserveWeight = 100000; // Exemplo de peso da reserva

    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 lpTokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 tokenAmount, uint256 lpTokenAmount);

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
        lpToken = new LiquidityPoolToken();
    }

    function addLiquidity(uint256 tokenAmount) public nonReentrant {
        require(tokenAmount > 0, "Token amount must be greater than 0");

        uint256 lpTokenAmount = calculateLPTokensToMint(tokenAmount);
        token.transferFrom(msg.sender, address(this), tokenAmount);
        lpToken.mint(msg.sender, lpTokenAmount);

        emit LiquidityAdded(msg.sender, tokenAmount, lpTokenAmount);
    }

    function removeLiquidity(uint256 lpTokenAmount) public nonReentrant {
        require(lpTokenAmount > 0, "LP Token amount must be greater than 0");

        uint256 tokenAmount = calculateTokensToWithdraw(lpTokenAmount);
        lpToken.burnFrom(msg.sender, lpTokenAmount);
        token.transfer(msg.sender, tokenAmount);

        emit LiquidityRemoved(msg.sender, tokenAmount, lpTokenAmount);
    }

    function calculatePrice() public view returns (uint256) {
        uint256 tokenSupply = token.totalSupply();
        uint256 tokenReserve = token.balanceOf(address(this));
        return tokenReserve.mul(reserveWeight).div(tokenSupply);
    }

    function calculateLPTokensToMint(uint256 tokenAmount) public view returns (uint256) {
        uint256 totalLiquidity = token.balanceOf(address(this));
        if (totalLiquidity == 0) {
            return tokenAmount;
        } else {
            uint256 totalLPTokens = lpToken.totalSupply();
            return tokenAmount.mul(totalLPTokens).div(totalLiquidity);
        }
    }

    function calculateTokensToWithdraw(uint256 lpTokenAmount) public view returns (uint256) {
        uint256 totalLPTokens = lpToken.totalSupply();
        uint256 tokenReserve = token.balanceOf(address(this));
        return lpTokenAmount.mul(tokenReserve).div(totalLPTokens);
    }
}
