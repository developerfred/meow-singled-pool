// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/solbase/src/auth/Owned.sol";

/// @title MEOWChild: A Custom ERC20 Token with Minting and Burning Capabilities
/// @dev Extends ERC20 and ERC20Permit for token standard functionalities and permit feature, respectively.
/// Incorporates ownership from the Owned contract for minting and burning.
contract MEOWChild is ERC20, ERC20Permit, Owned {

    /// @notice Initializes the token with name, symbol, initial supply, and owner.
    /// @param name_ The name of the token.
    /// @param symbol_ The token symbol.
    /// @param initialSupply The amount of the token to mint upon creation.
    /// @param owner_ The owner address with minting and burning privileges.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address owner_ 
    ) ERC20(name_, symbol_) ERC20Permit(name_) Owned(owner_) {
        require(owner_ != address(0), "Owner address cannot be the zero address");
        _mint(owner_, initialSupply);
    }
    
    /// @notice Mints tokens to a specified address.
    /// @dev Can only be called by the owner.
    /// @param to The address to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
    }

    /// @notice Burns tokens from a specified address.
    /// @dev Can only be called by the owner.
    /// @param from The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _burn(from, amount);
    }
}
