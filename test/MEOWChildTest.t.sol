// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MEOWChild } from "../src/MEOWChild.sol";

contract MEOWChildTest is PRBTest, StdCheats {
    MEOWChild meowChild;
    address owner = address(1);
    address recipient = address(2);

    function setUp() public {
        vm.startPrank(owner);
        meowChild = new MEOWChild("Test Token", "TST", 100e18, owner, address(0), address(4));
        vm.stopPrank();
    }

    function testInitialSupply() public {
        uint256 ownerBalance = meowChild.balanceOf(owner);
        assertEq(ownerBalance, 100e18, "Owner should have the initial supply");
    }

    function testMint() public {
        uint256 mintAmount = 50e18;
        vm.startPrank(owner);
        meowChild.mint(recipient, mintAmount);
        vm.stopPrank();

        uint256 recipientBalance = meowChild.balanceOf(recipient);
        assertEq(recipientBalance, mintAmount, "Recipient should receive minted amount");
    }

    function testBurn() public {
        // Testa a funcionalidade de burn
        uint256 burnAmount = 20e18;
        vm.startPrank(owner);
        meowChild.burn(owner, burnAmount);
        vm.stopPrank();

        uint256 remainingBalance = meowChild.balanceOf(owner);
        assertEq(remainingBalance, 80e18, "Owner balance should be reduced by burned amount");
    }

    function testFailUnauthorizedMint() public {
        vm.startPrank(recipient);
        meowChild.mint(recipient, 10e18);
        vm.stopPrank();
    }

    function testFailUnauthorizedBurn() public {
        vm.startPrank(recipient);
        meowChild.burn(owner, 10e18);
        vm.stopPrank();
    }
}
