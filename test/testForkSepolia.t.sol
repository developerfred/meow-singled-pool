// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import "../src/TokenExchange.sol";
import "../src/TokenFactory.sol";
import { ReserveTokenMock } from "../src/mock/TokenTest.sol";
import { MEOWChild } from "../src/MEOWChild.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title TokenExchangeTest
/// @notice This contract tests the functionality of the TokenExchange contract with additional scenarios.
contract TokenExchangeTest is PRBTest, StdCheats {
    TokenExchange tokenExchange;
    TokenFactory tokenFactory;
    ReserveTokenMock reserveToken;
    MEOWChild testToken;

    // Addresses of contracts on the Sepolia network
    address tokenFactoryAddress = 0xcfFa6a5951B3b01B1b08E386Ac1fb4B567eCc9fD;
    address tokenExchangeAddress = 0x2c4145a98611B2Dc6Ecfcd0bcc2A2f841E0916BF;
    address meowTestTokenAddress = 0x54ceABC39627d9cEB578BB5fC4CE3DB972b2ce69;
    address richWallet = address(4);
    address admin = address(0x7ED722577B0aB142EC6769879d8D6d17A4E96444);
    address user1 = address(2); // Added a second user
    address user2 = address(3); // Added a third user
    uint256 initialReserveTokenSupply = 1e26; // Increased to 100,000 ether
    uint256 tokenPrice = 5e18; // Adjusted to a higher price per token

    /// @notice Sets up the test environment.
    function setUp() public {
        // Create and select the Sepolia network fork
        uint256 sepoliaForkId = vm.createFork("https://eth-sepolia-public.unifra.io");
        vm.selectFork(sepoliaForkId);

        vm.rollFork(5608810);
        assertEq(block.number, 5608810);

        // Simulate funding wallets with funds
        vm.deal(richWallet, 100 ether); // Assign 100 ether to the rich wallet

        // Fund other wallets from the rich wallet
        vm.startPrank(richWallet);
        vm.deal(user1, 10 ether); // Fund user1 with 10 ether
        vm.deal(user2, 10 ether); // Fund user2 with 10 ether
        vm.stopPrank();

        // Continue with the rest of the setup
        setupAdmin();
        setupUser1(); // Add setup for user1
        setupUser2(); // Add setup for user2
    }

    /// @dev Sets up the admin account and necessary contracts.
    function setupAdmin() internal {
        vm.startPrank(admin);
        tokenFactory = TokenFactory(tokenFactoryAddress);
        tokenExchange = TokenExchange(tokenExchangeAddress);
        reserveToken = ReserveTokenMock(meowTestTokenAddress);

        address tokenAddress = tokenFactory.createToken(
            "UniqueCollectible", "UCOL", 5000 ether, 1_000_000, tokenPrice, admin, address(reserveToken), address(tokenExchange)
        );
        testToken = MEOWChild(tokenAddress);
        reserveToken.approve(address(testToken), 100 ether); // Increase the amount of reserve deposited
        testToken.depositReserveToken(100 ether);

        reserveToken.transfer(user1, 500 ether); // Increase the transferred amount for user1
        reserveToken.transfer(user2, 500 ether); // Increase the transferred amount for user2
        vm.stopPrank();
    }

    /// @dev Sets up the first user account.
    function setupUser1() internal {
        vm.startPrank(user1);
        reserveToken.approve(address(tokenExchange), 50 ether); // Allow a larger amount for buying
        vm.stopPrank();
    }

    /// @dev Sets up the second user account.
    function setupUser2() internal {
        vm.startPrank(user2);
        reserveToken.approve(address(tokenExchange), 50 ether); // Allow a larger amount for buying
        vm.stopPrank();
    }

    /// @notice Tests the token creation and exchange process with additional use cases.
    function testTokenCreationAndExchangeFork() public {
        // Test user1 buying and selling tokens
        testUser1TokenExchange();

        // Test user2 buying and selling tokens
        testUser2TokenExchange();
    }

    /// @dev Tests token buying and selling for user1.
    function testUser1TokenExchange() internal {
        uint256 reserveBalanceBefore = reserveToken.balanceOf(user1);

        buyTestTokens(user1);

        uint256 reserveBalanceAfterBuy = reserveToken.balanceOf(user1);
        assertTrue(
            reserveBalanceAfterBuy < reserveBalanceBefore, "User #1 reserve token balance should decrease after buying"
        );

        sellTestTokens(user1);

        uint256 reserveBalanceAfterSell = reserveToken.balanceOf(user1);
        assertTrue(
            reserveBalanceAfterSell > reserveBalanceAfterBuy,
            "User #1 reserve token balance should increase after selling"
        );
    }

    /// @dev Tests token buying and selling for user2.
    function testUser2TokenExchange() internal {
        uint256 reserveBalanceBefore = reserveToken.balanceOf(user2);

        buyTestTokens(user2);

        uint256 reserveBalanceAfterBuy = reserveToken.balanceOf(user2);
        assertTrue(
            reserveBalanceAfterBuy < reserveBalanceBefore, "User #2 reserve token balance should decrease after buying"
        );

        sellTestTokens(user2);

        uint256 reserveBalanceAfterSell = reserveToken.balanceOf(user2);
        assertTrue(
            reserveBalanceAfterSell > reserveBalanceAfterBuy,
            "User #2 reserve token balance should increase after selling"
        );
    }

    /// @dev Simulates a user buying tokens from the TokenExchange contract.
    /// @param userAddress The address of the user buying tokens.
    function buyTestTokens(address userAddress) internal {
        vm.startPrank(userAddress);
        tokenExchange.buyToken(address(testToken), 10 ether); // Adjust the amount of ether used to buy tokens
        uint256 userTestTokenBalance = testToken.balanceOf(userAddress);
        assertTrue(userTestTokenBalance > 0, "User should have test tokens after purchase");
        vm.stopPrank();
    }

    /// @dev Simulates a user selling tokens to the TokenExchange contract.
    /// @param userAddress The address of the user selling tokens.
    function sellTestTokens(address userAddress) internal {
        uint256 balanceUserBeforeSale = testToken.balanceOf(userAddress);
        console2.log("User address:", userAddress);
        console2.log("Balance of Test Token before sale:", balanceUserBeforeSale);
        uint256 reserveBalanceUserBeforeSale = reserveToken.balanceOf(userAddress);
        console2.log("Reserve Token balance before sale:", reserveBalanceUserBeforeSale);

        uint256 quarterTokens = balanceUserBeforeSale / 4; // Sell a quarter of the tokens
        console2.log("Selling quarter of tokens:", quarterTokens);

        require(quarterTokens > 0, "User does not have enough test tokens to sell");
        require(reserveBalanceUserBeforeSale > 0, "Reserve balance must be greater than zero");

        vm.startPrank(userAddress);
        testToken.approve(address(tokenExchange), quarterTokens);
        console2.log("Approved TokenExchange to spend tokens");

        tokenExchange.sellToken(address(testToken), quarterTokens);
        console2.log("Sell token transaction completed");

        uint256 balanceUserAfterSale = testToken.balanceOf(userAddress);
        console2.log("Balance of Test Token after sale:", balanceUserAfterSale);
        uint256 reserveBalanceUserAfterSale = reserveToken.balanceOf(userAddress);
        console2.log("Reserve Token balance after sale:", reserveBalanceUserAfterSale);

        vm.stopPrank();

        assertTrue(
            reserveBalanceUserAfterSale > reserveBalanceUserBeforeSale,
            "User's reserve token balance should increase after selling test tokens"
        );
    }
}
