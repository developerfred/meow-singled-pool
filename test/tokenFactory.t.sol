// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";


import { TokenFactory } from "../src/TokenFactory.sol";
import { LiquidityPool } from "../src/LiquidityPool.sol";
import { MEOWChild } from "../src/MEOWChild.sol";
import { MinterManager } from "../src/manager/MinterManager.sol";
import { MeowExchange } from "../src/exchange/MeowExchange.sol";
import { ReserveTokenMock } from "../src/mock/TokenTest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenFactoryTest is PRBTest, StdCheats {
    TokenFactory internal tokenFactory;
    ReserveTokenMock internal reserveToken;
    MeowExchange internal meowExchange;
    address internal reserveTokenAddress;
    address internal admin;

    

    function setUp() public virtual {
        admin = address(1); 
        setupContracts();        
    }


    function setupContracts() internal {
        vm.startPrank(admin);
        reserveToken = new ReserveTokenMock("ReserveToken", "RTK");
        tokenFactory = new TokenFactory(address(reserveToken));
        MinterManager minterManager = new MinterManager(address(tokenFactory));
        meowExchange = new MeowExchange(address(tokenFactory));
        tokenFactory.setMinterManager(address(minterManager));
        tokenFactory.setMeowExchange(address(meowExchange));
        vm.stopPrank();
    }


    function setupTokenAndPool() internal returns (address tokenAddress, address poolAddress) {
        console2.log("Setup Token and Liquidity Pool Creation");
    
        // Configurações iniciais
        string memory name = "Test Token";
        string memory symbol = "TTK";
        uint256 initialSupply = 1000 ether;
        uint8 decimals = 18;
        uint256 reserveWeight = 500000; // 50% em ppm
        uint256 slope = 1 ether; 
        bytes32 salt = keccak256("TestToken");
        uint256 reserveDeposit = 100 ether;
    
        // Verifica se o TokenFactory foi criado corretamente
        require(address(tokenFactory) != address(0), "TokenFactory should be deployed");
        
        // Mint tokens de reserva e aprovação
        reserveToken.mint(address(this), reserveDeposit);
        reserveToken.approve(address(tokenFactory), reserveDeposit);
        
        // Criação do token e do liquidity pool
        (tokenAddress, poolAddress) = tokenFactory.createToken(
            name, symbol, initialSupply, decimals, reserveWeight, slope, salt, reserveDeposit
        );
    
        // Verifica se os endereços do token e do pool não são zero
        require(tokenAddress != address(0), "Token address should not be zero");
        require(poolAddress != address(0), "Liquidity Pool address should not be zero");
    
        // Verificação adicional para garantir que o pool foi adicionado ao MeowExchange
        (IERC20 token, IERC20 reserveToken) = meowExchange.getPoolInfo(poolAddress);
        require(address(token) != address(0), "Token in pool does not exist");
        require(address(reserveToken) != address(0), "Reserve token in pool does not exist");
    }
    

    function prepareUserWithReserveTokens(address user, uint256 amount, address poolAddress) internal {
        console2.log("Checking user's initial reserve token balance");
        uint256 initialBalance = reserveToken.balanceOf(user);
        console2.log("Initial Balance:", initialBalance);
    
        console2.log("Minting Reserve Tokens to User");
        vm.startPrank(admin);
        reserveToken.mint(user, amount);
        vm.stopPrank();
    
        console2.log("Checking user's post-mint reserve token balance");
        uint256 postMintBalance = reserveToken.balanceOf(user);
        console2.log("Post-mint Balance:", postMintBalance);
        require(postMintBalance == initialBalance + amount, "Minting did not correctly adjust the user's balance");
    
        //vm.startPrank(user);
        //reserveToken.approve(poolAddress, amount);
        vm.stopPrank();
    }
    
    
    
    function performUserTokenTransactions(address user, address tokenAddress, address poolAddress, address exchangeAddress) internal {
        prepareUserWithReserveTokens(user, 30 ether, poolAddress);

        
        //uint256 userEtherBalance = user.balance;
        //require(userEtherBalance >= 30 ether, "User does not have enough Ether");
    
        IERC20 reserveTokenIERC20 = IERC20(LiquidityPool(poolAddress).reserveToken());
        IERC20 meowTokenIERC20 = IERC20(tokenAddress);

        vm.startPrank(user);
        uint256 UserTokenBalance = reserveTokenIERC20.balanceOf(user);
        require(UserTokenBalance > 0, "User does not have enough Ether");
        console2.log("Balance User:", UserTokenBalance);
        
        // Aprovação para gastar reserveToken
        vm.startPrank(user);
        reserveTokenIERC20.approve(exchangeAddress, 10 ether);

        // Compra de tokens
        vm.startPrank(user);
        MeowExchange(exchangeAddress).buyTokens(poolAddress, 7 ether);

        // Verifica se os tokens foram comprados corretamente
        uint256 postBuyUserTokenBalance = meowTokenIERC20.balanceOf(user);
        assertGt(postBuyUserTokenBalance, 0, "Token balance should increase after purchase");
        
        // Aprovação para gastar meowToken
        meowTokenIERC20.approve(exchangeAddress, 5 ether);
        
        // Venda de tokens
        MeowExchange(exchangeAddress).sellTokens(poolAddress, 5 ether);

        // Verifica se os tokens foram vendidos corretamente
        uint256 postSellUserTokenBalance = meowTokenIERC20.balanceOf(user);
        assertLt(postSellUserTokenBalance, postBuyUserTokenBalance, "Token balance should decrease after selling");

        vm.stopPrank();
    }
    
    

    function testTokenAndPoolCreation() external {
        vm.startPrank(admin);
        console2.log("Testing Token and Liquidity Pool Creation");
    
        // Configurações iniciais
        string memory name = "Test Token";
        string memory symbol = "TTK";
        uint256 initialSupply = 1000 ether;
        uint8 decimals = 18;
        uint256 reserveWeight = 500000; // 50% em ppm
        uint256 slope = 1 ether; 
        bytes32 salt = keccak256("TestToken");
        uint256 reserveDeposit = 100 ether;
    
        // Verifica se o TokenFactory foi criado corretamente
        require(address(tokenFactory) != address(0), "TokenFactory should be deployed");
    
        // Mint tokens de reserva e aprovação
        reserveToken.mint(address(this), reserveDeposit);
        reserveToken.approve(address(tokenFactory), reserveDeposit);


    
        // Criação do token e do liquidity pool
        (address tokenAddress, address poolAddress) = tokenFactory.createToken(
            name, symbol, initialSupply, decimals, reserveWeight, slope, salt, reserveDeposit
        );
    
        // Verifica se os endereços do token e do pool não são zero
        require(tokenAddress != address(0), "Token address should not be zero");
        require(poolAddress != address(0), "Liquidity Pool address should not be zero");

        // Carrega instâncias dos contratos
        // MEOWChild meowToken = MEOWChild(tokenAddress);
        LiquidityPool liquidityPool = LiquidityPool(poolAddress);
    
        // Verifica as propriedades do LiquidityPool
        assertEq(liquidityPool.getReserveWeight(), reserveWeight, "Incorrect reserve weight");
        assertEq(liquidityPool.getSlope(), slope, "Incorrect slope value");

    
        vm.stopPrank();
    }


    function testUserBuyAndSellTokens() external {
        console2.log("Testing User Buy and Sell Tokens");
        address user = address(2);
        
        vm.prank(admin);
        (address tokenAddress, address poolAddress) = setupTokenAndPool();
        vm.stopPrank();

        vm.prank(user);
        performUserTokenTransactions(user, tokenAddress, poolAddress, address(meowExchange));
        vm.stopPrank();
    }
    
    
    
    
}
