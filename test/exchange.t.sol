// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { TokenFactory } from "../src/TokenFactory.sol";
import { LiquidityPool } from "../src/LiquidityPool.sol";
import "../src/MEOWChild.sol";
import { ReserveTokenMock } from "../src/mock/TokenTest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenFactoryTest is PRBTest, StdCheats {
    TokenFactory internal tokenFactory;
    ReserveTokenMock internal reserveToken;

    address internal admin;
    address internal creator;
    address internal userTest;
    address internal buyer;

    function setUp() public virtual {
        admin = address(1);
        creator = address(2);
        userTest = address(3);
        buyer = address(5);
        setupContracts();
    }

    function setupContracts() internal {
        vm.startPrank(admin);
        reserveToken = new ReserveTokenMock("MeowReserveToken", "MeowR");
        tokenFactory = new TokenFactory();
        tokenFactory.initialize(address(reserveToken));
        vm.stopPrank();
    }

    function setupTokenAndPool() internal returns (address tokenAddress, address poolAddress) {
        console2.log("Admin is initiating the setup for Token and Liquidity Pool");

        // Parameters for token creation
        string memory name = "Codingsh Token";
        string memory symbol = "CodMeow";
        uint256 initialSupply = 100_000 ether;
        uint256 reserveWeight = 3000;
        uint256 slope = 1 ether;

        // Creator balance log before token creation
        uint256 creatorReserveTokenBalanceBefore = reserveToken.balanceOf(creator);
        console2.log("Creator's Reserve Token Balance Before Token Creation:", creatorReserveTokenBalanceBefore);

        // Creation of the token and liquidity pool

        (tokenAddress, poolAddress) =
            tokenFactory.createToken(name, symbol, initialSupply, reserveWeight, slope, creator);

        // Checking and logging creator balance after token creation
        IERC20 newToken = IERC20(tokenAddress);
        uint256 creatorNewTokenBalanceAfter = newToken.balanceOf(creator);
        console2.log("Creator's New Token Balance After Token Creation:", creatorNewTokenBalanceAfter);
        vm.stopPrank();

        require(tokenAddress != address(0) && poolAddress != address(0), "Token or Pool creation failed");

        // Final logs
        console2.log("Token and Liquidity Pool were created successfully.", tokenAddress, poolAddress);
        console2.log("Creator of the Token:", creator);
    }

    function fundingPool(uint256 amount, address poolAddress, address tokenAddressA, address tokenAddressB) internal {
        IERC20 tokenA = IERC20(tokenAddressA);
        IERC20 tokenB = IERC20(tokenAddressB);

        // Check admin balance for token and token before proceeding
        uint256 balanceA = tokenA.balanceOf(userTest); // Meow Token
        uint256 balanceB = tokenB.balanceOf(userTest); // New Token
        require(balanceA >= amount, "Admin does not have enough tokenA");
        require(balanceB >= amount, "Admin does not have enough tokenB");

        console2.log("Token A Balance Before Funding:", balanceA);
        console2.log("Token B Balance Before Funding:", balanceB);

        // Approval of tokens for the LiquidityPool contract
        tokenA.approve(poolAddress, amount);
        tokenB.approve(poolAddress, amount);

        // Adding liquidity to the pool
        LiquidityPool(poolAddress).addLiquidity(amount, amount);

        // Checks after adding liquidity
        uint256 balancePoolA = tokenA.balanceOf(poolAddress);
        uint256 balancePoolB = tokenB.balanceOf(poolAddress);
        console2.log("Pool Balance Token A", balancePoolA);
        console2.log("Pool Balance Token B", balancePoolB);

        //Admin balance checks after adding liquidity
        uint256 adminBalanceAAfter = tokenA.balanceOf(creator);
        uint256 adminBalanceBAfter = tokenB.balanceOf(creator);
        console2.log("Admin Token A Balance After Funding:", adminBalanceAAfter);
        console2.log("Admin Token B Balance After Funding:", adminBalanceBAfter);
    }

    // working  transfReserve

    function transferReserveTokensToUser(address user, uint256 amount) internal {
        console2.log("Transferring Reserve Tokens to User");
        vm.startPrank(admin);
        reserveToken.transfer(user, amount);
        vm.stopPrank();
        console2.log("Transfer complete, user now has reserve tokens");
    }

    function testUserBuyAndSellTokens() external {
        console2.log("Testing User Buy and Sell Tokens");

        // Admin sets up the pool and token
        (address tokenAddress, address poolAddress) = setupTokenAndPool();

        vm.startPrank(creator);
        IERC20 TokenA = IERC20(address(tokenAddress));
        TokenA.approve(userTest, 2 ether);
        TokenA.transfer(userTest, 2 ether);
        vm.stopPrank();

        vm.startPrank(admin);
        reserveToken.approve(userTest, 2 ether);
        reserveToken.transfer(userTest, 2 ether);
        reserveToken.transfer(buyer, 3 ether);
        vm.stopPrank();

        uint256 userTestReserve = reserveToken.balanceOf(userTest);
        console2.log("user test balance:", userTestReserve);

        vm.startPrank(userTest);
        uint256 fudingAmount = 1 ether;
        fundingPool(fudingAmount, poolAddress, tokenAddress, address(reserveToken));
        vm.stopPrank();

        uint256 PoolBalance = TokenA.balanceOf(poolAddress);
        console2.log("Poool Balance", PoolBalance / 10 ** 18);

        vm.startPrank(buyer);

        uint256 amount = 1 ether;
            

        reserveToken.approve(poolAddress, amount);
        LiquidityPool(poolAddress).swapTokens(address(reserveToken), amount);
        uint256 buyerNewTokenBalance = TokenA.balanceOf(buyer);
        console2.log("Buyer Balance", buyerNewTokenBalance);
        console2.log("Poool Balance after buy", PoolBalance / 10 ** 18);

        vm.stopPrank();
    }

    function performUserTokenTransactions(address user, address tokenAddress, address poolAddress) internal {
        IERC20 reserveTokenIERC20 = IERC20(address(reserveToken));
        IERC20 meowTokenIERC20 = IERC20(tokenAddress);

        // User approves exchange to spend reserve tokens
        uint256 approveAmount = 3 ether;
        vm.startPrank(user); // Prank as user to approve spending of reserve tokens
        reserveTokenIERC20.approve(poolAddress, approveAmount);
        console2.log("User approved exchange to spend reserve tokens");
        vm.stopPrank(); // Stop pranking

        // User buys tokens from the exchange
        uint256 buyAmount = 0.1 ether;
        uint256 startBalance = meowTokenIERC20.balanceOf(user);

        console2.log("buy tokens", tokenAddress);
        console2.log("user Start Balance", startBalance);
        LiquidityPool(poolAddress).swapTokens(tokenAddress, buyAmount); // Assuming this swaps reserve tokens for meow
            // tokens
        uint256 postBuyBalance = meowTokenIERC20.balanceOf(user);
        console2.log("User bought tokens, new balance:", postBuyBalance);
    }
}
