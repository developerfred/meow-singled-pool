// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "./LiquidityPool.sol";
import "./MEOWChild.sol";
import "lib/solbase/src/auth/Owned.sol";
import "lib/solbase/src/utils/ReentrancyGuard.sol";


contract TokenFactory is ReentrancyGuard {
    address public defaultReserveToken;
    
    constructor(address _defaultReserveToken) {
        defaultReserveToken = _defaultReserveToken;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals,
        uint256 reserveWeight,
        uint256 slope,
        bytes32 salt,
        uint256 reserveDeposit
    ) public nonReentrant returns (address tokenAddress, address poolAddress) {
        IERC20 reserveToken = IERC20(defaultReserveToken);

        bytes memory bytecode = type(MEOWChild).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(name, symbol, initialSupply, decimals, msg.sender));
        tokenAddress = create3(salt, bytecode);
        
        poolAddress = address(new LiquidityPool(tokenAddress, defaultReserveToken, msg.sender, reserveWeight, slope));
        LiquidityPool(poolAddress).setTokenFactory(address(this));

        require(reserveToken.transferFrom(msg.sender, address(this), reserveDeposit), "Reserve deposit transfer failed");
        require(reserveToken.approve(poolAddress, reserveDeposit), "Reserve deposit approval failed");
        LiquidityPool(poolAddress).receiveReserveDeposit(reserveDeposit);
    }

    function create3(bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }
}
