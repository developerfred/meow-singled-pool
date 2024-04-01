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
/// @notice This contract tests the functionality of the TokenExchange contract.
contract TokenExchangeTest is PRBTest, StdCheats {
    TokenExchange tokenExchange;
    TokenFactory tokenFactory;
    ReserveTokenMock reserveToken;
    MEOWChild testToken;

    address admin = address(1);
    address user1 = address(2); // Added a second user
    address user2 = address(3); // Added a third user
    uint256 initialReserveTokenSupply = 1e26; // Increased to 100,000 ether
    uint256 tokenPrice = 5e18; // Adjusted to a higher price per token

    /// @notice Sets up the test environment.
    function setUp() public {
        setupAdmin();
        setupUser1(); // Added setup for user 1
        setupUser2(); // Added setup for user 2
    }

    /// @dev Sets up the admin account and necessary contracts.
    function setupAdmin() internal {
        vm.startPrank(admin);
        reserveToken = new ReserveTokenMock("Reserve Token", "RST");
        reserveToken.mint(admin, initialReserveTokenSupply);

        tokenFactory = new TokenFactory();
        tokenExchange = new TokenExchange(address(tokenFactory));

        address tokenAddress = tokenFactory.createToken(
            "UniqueCollectible", "TST", 5000 ether, 1_000_000, tokenPrice, admin, address(reserveToken), address(tokenExchange)
        );
        testToken = MEOWChild(tokenAddress);
        reserveToken.approve(address(testToken), 100 ether); // Increase the amount of reserve deposited
        testToken.depositReserveToken(100 ether);

        reserveToken.transfer(user1, 500 ether); // Increase the transferred amount for user 1
        reserveToken.transfer(user2, 500 ether); // Increase the transferred amount for user 2
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

    /// @notice Tests the token creation and exchange process.
    function testTokenFactoryExchange() public {
        buyTestTokens(user1); // Change to user 1

        sellTestTokens(user1); // Change to user 1

        // Additional test for user 2
        buyTestTokens(user2);
        sellTestTokens(user2);
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
