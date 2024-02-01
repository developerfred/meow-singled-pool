// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/solbase/src/utils/ReentrancyGuard.sol";
import "lib/solbase/src/utils/SafeTransferLib.sol";
import "../LiquidityPool.sol";

contract MeowExchange is ReentrancyGuard {
    address public tokenFactory;
    struct PoolInfo {
        IERC20 token;
        IERC20 reserveToken;
    }

    // Mapeamento de endereço do pool para suas informações
    mapping(address => PoolInfo) public pools;

    constructor(address _tokenFactory) {
        require(_tokenFactory != address(0), "TokenFactory address cannot be 0");
        tokenFactory = _tokenFactory;
    }

    modifier onlyTokenFactory() {
        require(msg.sender == tokenFactory, "Only TokenFactory can call this function");
        _;
    }

    // Função para adicionar um novo LiquidityPool ao exchange
    function addLiquidityPool(address _poolAddress) public onlyTokenFactory {
        LiquidityPool pool = LiquidityPool(_poolAddress);
        address tokenAddress = address(pool.token()); 
        address reserveTokenAddress = address(pool.reserveToken()); 
        pools[_poolAddress] = PoolInfo({
            token: IERC20(tokenAddress),
            reserveToken: IERC20(reserveTokenAddress)
        });
    }
    

    // Função para realizar a compra de tokens
    function buyTokens(address _poolAddress, uint256 reserveTokenAmount) public nonReentrant {
        PoolInfo storage pool = pools[_poolAddress];
        require(address(pool.token) != address(0), "Pool does not exist");
        require(reserveTokenAmount > 0, "Amount must be greater than 0");
        require(pool.reserveToken.allowance(msg.sender, address(this)) >= reserveTokenAmount, "Insufficient allowance");

        SafeTransferLib.safeTransferFrom(address(pool.reserveToken), msg.sender, address(this), reserveTokenAmount);
        SafeTransferLib.safeApprove(address(pool.reserveToken), _poolAddress, reserveTokenAmount);

        LiquidityPool(_poolAddress).buyTokens(reserveTokenAmount);
    }
    
    // Função para realizar a venda de tokens
    function sellTokens(address _poolAddress, uint256 tokenAmount) public nonReentrant {
        PoolInfo storage pool = pools[_poolAddress];
        require(address(pool.token) != address(0), "Pool does not exist");
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(pool.token.allowance(msg.sender, address(this)) >= tokenAmount, "Insufficient allowance");

        SafeTransferLib.safeTransferFrom(address(pool.token), msg.sender, address(this), tokenAmount);
        SafeTransferLib.safeApprove(address(pool.token), _poolAddress, tokenAmount);

        LiquidityPool(_poolAddress).sellTokens(tokenAmount);
    }

    // Função para obter informações do pool de liquidez
    function getPoolInfo(address _poolAddress) public view returns (IERC20, IERC20) {
        PoolInfo storage pool = pools[_poolAddress];
        return (pool.token, pool.reserveToken);
    }

}
