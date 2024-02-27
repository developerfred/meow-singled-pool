// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { TokenFactory } from "../src/TokenFactory.sol";
import { TokenExchange } from "../src/TokenExchange.sol";
import "../src/MEOWChild.sol";
import { ReserveTokenMock } from "../src/mock/TokenTest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Test Suite for TokenFactory and TokenExchange
/// @notice This contract tests the creation of MEOWChild tokens and their exchange process.
contract TokenFactoryTest is PRBTest, StdCheats {
    TokenFactory internal tokenFactory;
    TokenExchange internal tokenExchange;
    ReserveTokenMock internal reserveToken;

    address internal admin;
    address internal creator;
    address internal user;
    address internal buyer;

    /// @notice Sets up the test environment with necessary contract deployments and initial configurations.
    function setUp() public virtual {
        admin = address(1);
        creator = address(2);
        user = address(3);
        buyer = address(5);
        setupContracts();
    }

    /// @dev Deploys contracts and initializes them with appropriate values for testing.
    function setupContracts() internal {
        vm.startPrank(admin);
        reserveToken = new ReserveTokenMock("MeowReserveToken", "MeowR");
        reserveToken.mint(address(this), 1_000_000_000 ether);
        tokenFactory = new TokenFactory();
        tokenFactory.initialize(address(reserveToken));
        tokenExchange = new TokenExchange(address(tokenFactory));

        reserveToken.transfer(address(tokenExchange), 100_000 ether);
        vm.stopPrank();
    }

    /// @dev Creates a token and prepares it for exchange, logging the process.
    /// @return tokenAddress The address of the newly created MEOWChild token.
    function setupTokenAndPool() internal returns (address tokenAddress) {
        console2.log("Admin is initiating the setup for Token");

        string memory name = "Codingsh Token";
        string memory symbol = "CodMeow";
        uint256 initialSupply = 100_000_000 ether;
        uint256 reserveWeight = 3000;
        uint256 slope = 1 ether;

        tokenAddress = tokenFactory.createToken(name, symbol, initialSupply, reserveWeight, slope, creator, address(reserveToken), address(tokenExchange));

        require(tokenAddress != address(0), "Token creation failed");
        console2.log("Token were created successfully.", tokenAddress);
        console2.log("Creator of the Token:", creator);
    }

    /// @notice Tests the entire process of token creation and its subsequent exchange.
    function testTokenCreationAndExchange() external {
        address tokenAddress = setupTokenAndPool();

        transferReserveTokensToUser(100 ether);
        userBuysToken(tokenAddress, 50 ether);
        verifyTokenPurchase(tokenAddress);
    }

    /// @dev Simulates the transfer of reserve tokens to a user's account.
    /// @param amount The amount of reserve tokens to be transferred.
    function transferReserveTokensToUser(uint256 amount) internal {
        vm.startPrank(admin);
        reserveToken.transfer(user, amount);
        vm.stopPrank();
        console2.log("Transferred reserve tokens to user:", amount);
    }

    /// @dev Simulates a user buying tokens from the TokenExchange.
    /// @param tokenAddress The address of the token to buy.
    /// @param amount The amount of reserve tokens to spend.
    function userBuysToken(address tokenAddress, uint256 amount) internal {
        vm.startPrank(user);
        reserveToken.approve(address(tokenExchange), amount);
        tokenExchange.buyToken(tokenAddress, amount);
        vm.stopPrank();
        console2.log("User purchased tokens:", amount);
    }

    /// @dev Verifies the results of the token purchase by checking the user's balances.
    /// @param tokenAddress The address of the purchased token.
    function verifyTokenPurchase(address tokenAddress) internal {
        uint256 userTokenBalance = IERC20(tokenAddress).balanceOf(user);
        uint256 userReserveBalanceAfterPurchase = reserveToken.balanceOf(user);

        console2.log("User's Token Balance After Purchase:", userTokenBalance);
        console2.log("User's Reserve Balance After Purchase:", userReserveBalanceAfterPurchase);
        
        require(userTokenBalance > 0, "Token purchase failed");
    }
}
