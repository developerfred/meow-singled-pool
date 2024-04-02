// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/solady/src/auth/OwnableRoles.sol";
import { SafeTransferLib } from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title MEOWChild: A Custom ERC20 Token with Minting and Burning Capabilities
/// @dev Extends ERC20 and ERC20Permit for token standard functionalities and permit feature, respectively.
/// Incorporates ownership from the OwnableRoles contract for minting, burning, and exchange roles management.
contract MEOWChild is ERC20, ERC20Permit, OwnableRoles {
    /// @notice Role identifier for addresses with minting permissions.
    /// @dev Assigned as a bit mask for efficient role management.
    uint256 public constant MINTER_ROLE = 1 << 1;

    /// @notice Role identifier for addresses with burning permissions.
    /// @dev Assigned as a bit mask for efficient role management.
    uint256 public constant BURNER_ROLE = 1 << 2;

    /// @notice Role identifier for exchange addresses.
    /// @dev Assigned as a bit mask for efficient role management.
    uint256 public constant DEX_ROLE = 1 << 3;

    /// @notice Address of the reserve token.
    /// @dev Used for deposit and withdrawal operations by this contract.
    address public reserveTokenAddress;

    /// @notice Emitted when reserve tokens are deposited into the contract.
    /// @param depositor Address depositing the reserve tokens.
    /// @param amount Amount of reserve tokens deposited.
    event ReserveTokenDeposited(address indexed depositor, uint256 amount);

    /// @notice Emitted when reserve tokens are withdrawn from the contract.
    /// @param receiver Address receiving the reserve tokens.
    /// @param amount Amount of reserve tokens withdrawn.
    event ReserveTokenWithdrawn(address indexed receiver, uint256 amount);

    /// @notice Emitted when tokens are minted.
    /// @param to Address receiving the minted tokens.
    /// @param amount Amount of tokens minted.
    event TokensMinted(address indexed to, uint256 amount);

    /// @notice Emitted when tokens are burned.
    /// @param from Address from which tokens are burned.
    /// @param amount Amount of tokens burned.
    event TokensBurned(address indexed from, uint256 amount);

    /// inheritdoc ERC20
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address owner_,
        address exchange_,
        address reserveTokenAddress_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        OwnableRoles()
    {
        require(owner_ != address(0), "Owner address cannot be the zero address");
        require(reserveTokenAddress_ != address(0), "Reserve token address cannot be the zero address");
        _mint(owner_, initialSupply);
        _grantRoles(owner_, MINTER_ROLE | BURNER_ROLE);
        _grantRoles(exchange_, MINTER_ROLE | BURNER_ROLE | DEX_ROLE);
        reserveTokenAddress = reserveTokenAddress_;
    }

    /// inheritdoc ERC20
    /// @dev Can only be called by addresses with MINTER_ROLE.
    function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /// inheritdoc ERC20
    /// @dev Can only be called by addresses with BURNER_ROLE.
    function burn(address from, uint256 amount) external onlyRoles(BURNER_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /// @notice Allows depositing of reserve tokens into the contract.
    /// @dev Transfers reserve tokens from the caller to the contract.
    /// @param amount Amount of reserve tokens to deposit.
    function depositReserveToken(uint256 amount) external {
        SafeTransferLib.safeTransferFrom(reserveTokenAddress, msg.sender, address(this), amount);
        emit ReserveTokenDeposited(msg.sender, amount);
    }

    /// @notice Allows withdrawal of reserve tokens from the contract.
    /// @dev Can only be called by addresses with DEX_ROLE.
    /// @param to Address to receive the withdrawn reserve tokens.
    /// @param amount Amount of reserve tokens to withdraw.
    function withdrawReserveToken(address to, uint256 amount) external onlyRoles(DEX_ROLE) {
        SafeTransferLib.safeTransfer(reserveTokenAddress, to, amount);
        emit ReserveTokenWithdrawn(to, amount);
    }

    /// @notice Checks and returns the balance of the reserve token held by this contract.
    /// @dev Intended for external calls to assess reserve token holdings.
    /// @return The amount of reserve tokens held by this contract.
    function checkReserveTokenBalance() external view returns (uint256) {
        uint256 balance = IERC20(reserveTokenAddress).balanceOf(address(this));
        return balance;
    }
}
