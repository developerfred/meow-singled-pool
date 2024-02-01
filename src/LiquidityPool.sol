// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "lib/solbase/src/auth/Owned.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/solbase/src/utils/ReentrancyGuard.sol";
import "lib/solbase/src/utils/SafeTransferLib.sol";
import "./MEOWChild.sol";
import "./manager/MinterManager.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

interface MeowERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract LiquidityPool is Owned, ReentrancyGuard {    

    address public tokenFactory;
    address public minterManagerAddress;
    MeowERC20 public token;
    MeowERC20 public reserveToken;

    uint256 private reserveWeight; 
    uint256 private slope; 

        
    event ReserveWeightUpdated(uint256 newWeight);
    event SlopeUpdated(uint256 newSlope);

    modifier onlyOwnerOrTokenFactory() {
        require(msg.sender == owner || msg.sender == tokenFactory, "Not authorized");
        _;
    }

    constructor(
        address _tokenAddress,
        address _reserveTokenAddress,
        address _owner,
        uint256 _initialReserveWeight,
        uint256 _initialSlope,
        address _minterManagerAddress
    ) Owned(_owner) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_reserveTokenAddress != address(0), "Invalid reserve token address");
        token = MeowERC20(_tokenAddress);
        reserveToken = MeowERC20(_reserveTokenAddress);
        reserveWeight = _initialReserveWeight;
        slope = _initialSlope;
        minterManagerAddress = _minterManagerAddress;
    }

    function setReserveWeight(uint256 _newWeight) external onlyOwner {
        require(_newWeight > 0 && _newWeight <= 1000000, "Invalid reserve weight");
        reserveWeight = _newWeight;
        emit ReserveWeightUpdated(_newWeight);
    }

    function setSlope(uint256 _newSlope) external onlyOwner {
        require(_newSlope > 0, "Invalid slope value");
        slope = _newSlope;
        emit SlopeUpdated(_newSlope);
    }

    function getReserveWeight() public view returns (uint256) {
        return reserveWeight;
    }

    function getSlope() public view returns (uint256) {
        return slope;
    }


    function buyTokens(uint256 reserveTokenAmount) public nonReentrant {
        require(reserveTokenAmount > 0, "Amount must be greater than 0");
        uint256 tokenAmount = calculatePurchaseReturn(reserveTokenAmount);
        require(tokenAmount > 0, "Invalid token amount");
        
        SafeTransferLib.safeTransferFrom(address(reserveToken), msg.sender, address(this), reserveTokenAmount);
        // Transferir tokens do pool para o comprador ao invés de mintar
        SafeTransferLib.safeTransfer(address(token), msg.sender, tokenAmount);
    }
    
      
    function sellTokens(uint256 tokenAmount) public nonReentrant {
        require(tokenAmount > 0, "Amount must be greater than 0");
        uint256 reserveTokenAmount = calculateSaleReturn(tokenAmount);
        require(reserveTokenAmount > 0, "Invalid reserve token amount");
        
        SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), tokenAmount);
        // Transferir tokens de reserva do pool para o vendedor ao invés de queimar
        SafeTransferLib.safeTransfer(address(reserveToken), msg.sender, reserveTokenAmount);
    }

    function _calculateReturn(
        uint256 amount,
        uint256 supplyAmount,
        uint256 reserveAmount,
        bool isPurchase
    ) internal view returns (uint256) {
        uint256 weightUD60x18 = (1000000.ud60x18()).div(reserveWeight.ud60x18());

        if (isPurchase) {
            // Cálculo para compra
            return amount.ud60x18().mul(supplyAmount.ud60x18()).div(reserveAmount.ud60x18().mul(weightUD60x18)).intoUint256();
        } else {
            // Cálculo para venda
            return amount.ud60x18().mul(reserveAmount.ud60x18()).div(supplyAmount.ud60x18().mul(weightUD60x18)).intoUint256();
        }
    }

    function calculatePurchaseReturn(uint256 reserveTokenAmount) public view returns (uint256) {
        uint256 reserveBalance = reserveToken.balanceOf(address(this));
        uint256 supply = token.totalSupply();

        return _calculateReturn(reserveTokenAmount, supply, reserveBalance, true);
    }

    function calculateSaleReturn(uint256 tokenAmount) public view returns (uint256) {
        uint256 reserveBalance = reserveToken.balanceOf(address(this));
        uint256 supply = token.totalSupply();

        return _calculateReturn(tokenAmount, supply, reserveBalance, false);
    }
    function receiveReserveDeposit(uint256 amount) public nonReentrant {
        require(msg.sender == tokenFactory, "Only token factory can deposit reserve");
        require(amount > 0, "Amount must be greater than 0");
        
        SafeTransferLib.safeTransferFrom(address(reserveToken), msg.sender, address(this), amount);
    }

    function setTokenFactory(address _tokenFactory) external onlyOwner {
        require(_tokenFactory != address(0), "Invalid token factory address");
        tokenFactory = _tokenFactory;
    }

    function authorizeWithManager(address meowChild) external onlyOwnerOrTokenFactory {
        MinterManager(minterManagerAddress).authorizePool(meowChild, address(this));
    }
     
}
