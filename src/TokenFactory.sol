// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "./LiquidityPool.sol";
import "./MEOWChild.sol";
import "./manager/MinterManager.sol";
import "lib/solbase/src/auth/Owned.sol";
import "lib/solbase/src/utils/ReentrancyGuard.sol";
import "./exchange/MeowExchange.sol";


contract TokenFactory is ReentrancyGuard, Owned {
    address public minterManager;
    address public meowExchange;
    address public defaultReserveToken;
    
    constructor(address _defaultReserveToken) Owned(msg.sender) {
        defaultReserveToken = _defaultReserveToken;
    }

    function setMinterManager(address _minterManager) external onlyOwner {
        minterManager = _minterManager;
    }

    /**
     * @dev Creates a new token and a corresponding liquidity pool.
     * @param name The name of the token to be created.
     * @param symbol The symbol of the token.
     * @param initialSupply The initial supply of the token.
     * @param decimals The number of decimal places for the token.
     * @param reserveWeight The weight of the reserve in the liquidity pool.
     * @param slope The slope factor used in the liquidity pool's pricing algorithm.
     * @param salt A unique salt for deterministic contract creation.
     * @param reserveDeposit The initial deposit in the reserve of the liquidity pool.
     * @return tokenAddress The address of the newly created token.
     * @return poolAddress The address of the newly created liquidity pool.
     *
     * The function emits a transfer of reserve tokens from the user to the contract
     * and an approval for the liquidity pool to spend these tokens.
     *
     * The `reserveWeight` parameter influences the pricing of the token in the liquidity pool.
     * It's a factor in determining how much the price increases with each purchase. A higher weight
     * results in a slower price increase.
     *
     * The `slope` parameter is part of the pricing curve equation for the liquidity pool. It determines
     * the rate at which the price increases as the token supply decreases. A steeper slope means a faster
     * price increase as the supply diminishes.
     */


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
        require(bytes(name).length > 0, "Invalid name");
        require(bytes(symbol).length > 0, "Invalid symbol");
        require(initialSupply > 0, "Initial supply must be greater than 0");
        require(reserveWeight > 0, "Reserve weight must be greater than 0");
        require(slope > 0, "Slope must be greater than 0");
        require(reserveDeposit > 0, "Reserve deposit must be greater than 0");

        // Generate a unique salt based on user input and additional factors
        bytes32 uniqueSalt = keccak256(abi.encodePacked(msg.sender, salt, block.timestamp));
        
        IERC20 reserveToken = IERC20(defaultReserveToken);

        bytes memory bytecode = type(MEOWChild).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(name, symbol, initialSupply, decimals, msg.sender));
        tokenAddress = create3(uniqueSalt, bytecode);
        
        poolAddress = address(new LiquidityPool(tokenAddress,  defaultReserveToken, address(this), reserveWeight, slope, minterManager));
        LiquidityPool(poolAddress).setTokenFactory(address(this));
      
        require(reserveToken.transferFrom(msg.sender, address(this), reserveDeposit), "Reserve deposit transfer failed");
        require(reserveToken.approve(poolAddress, reserveDeposit), "Reserve deposit approval failed");
        LiquidityPool(poolAddress).receiveReserveDeposit(reserveDeposit);
        
        if (meowExchange != address(0)) {
            MeowExchange(meowExchange).addLiquidityPool(poolAddress);
        }
    }

    function create3(bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }


    function setMeowExchange(address _meowExchange) external onlyOwner {
        require(_meowExchange != address(0), "MeowExchange address cannot be 0");
        meowExchange = _meowExchange;
    }
}
