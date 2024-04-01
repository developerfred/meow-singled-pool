// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/solady/src/auth/OwnableRoles.sol";
import { SafeTransferLib } from "lib/solady/src/utils/SafeTransferLib.sol";


/// @title MEOWChild: A Custom ERC20 Token with Minting and Burning Capabilities
/// @dev Extends ERC20 and ERC20Permit for token standard functionalities and permit feature, respectively.
/// Incorporates ownership from the Owned contract for minting and burning.
contract MEOWChild is ERC20, ERC20Permit, OwnableRoles {

    uint256 public constant MINTER_ROLE = 1 << 1;
    uint256 public constant BURNER_ROLE = 1 << 2;
    uint256 public constant DEX_ROLE = 1 << 3;
    address public reserveTokenAddress;

    event ReserveTokenDeposited(address indexed depositor, uint256 amount);
    event ReserveTokenWithdrawn(address indexed receiver, uint256 amount);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /// @notice Initializes the token with name, symbol, initial supply, and owner.
    /// @param name_ The name of the token.
    /// @param symbol_ The token symbol.
    /// @param initialSupply The amount of the token to mint upon creation.
    /// @param owner_ The owner address with minting and burning privileges.
    /// @param exchange_ The exchange address
    /// @param reserveTokenAddress_ The ReserveToken address
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address owner_,
        address exchange_,
        address reserveTokenAddress_
    ) ERC20(name_, symbol_) ERC20Permit(name_) OwnableRoles() {
        require(owner_ != address(0), "Owner address cannot be the zero address");
        require(reserveTokenAddress_ != address(0), "Reserve token address cannot be the zero address");
        _mint(owner_, initialSupply);
        _grantRoles(owner_, MINTER_ROLE | BURNER_ROLE);
        _grantRoles(exchange_, MINTER_ROLE | BURNER_ROLE | DEX_ROLE);
        reserveTokenAddress = reserveTokenAddress_;
    }

    /// @notice Mints tokens to a specified address.
    /// @dev Can only be called by the owner.
    /// @param to The address to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /// @notice Burns tokens from a specified address.
    /// @dev Can only be called by the owner.
    /// @param from The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) external onlyRoles(BURNER_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }


    function depositReserveToken(uint256 amount) external {
        SafeTransferLib.safeTransferFrom(reserveTokenAddress, msg.sender, address(this), amount);
        emit ReserveTokenDeposited(msg.sender, amount);
    }



    function withdrawReserveToken(address to, uint256 amount) external onlyRoles(DEX_ROLE) {
        SafeTransferLib.safeTransfer(reserveTokenAddress, to, amount);
        emit ReserveTokenWithdrawn(to, amount);
    }

    /// @notice Checks the balance of the reserve token held by this contract.
    /// @dev Useful for external checks on reserve token holdings.
    /// @return The amount of reserve tokens held.
    function checkReserveTokenBalance() external view returns (uint256) {
        uint256 balance = IERC20(reserveTokenAddress).balanceOf(address(this));
        return balance;
    }


}
