// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "lib/solbase/src/tokens/ERC20/ERC20.sol";
import "lib/solbase/src/auth/Owned.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/solbase/src/utils/ReentrancyGuard.sol";

interface MeowERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract LiquidityPool is Owned {    

    address public tokenFactory;
    MeowERC20 public token;
    MeowERC20 public reserveToken;

    uint256 private reserveWeight; 
    uint256 private slope; 
        
    event ReserveWeightUpdated(uint256 newWeight);
    event SlopeUpdated(uint256 newSlope);

    constructor(
        address _tokenAddress,
        address _reserveTokenAddress,
        address _owner,
        uint256 _initialReserveWeight,
        uint256 _initialSlope
    ) Owned(_owner) {
        token = MeowERC20(_tokenAddress);
        reserveToken = MeowERC20(_reserveTokenAddress);
        reserveWeight = _initialReserveWeight;
        slope = _initialSlope;
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


    function buyTokens(uint256 reserveTokenAmount) public {
        require(reserveTokenAmount > 0, "Amount must be greater than 0");
        uint256 tokenAmount = calculatePurchaseReturn(reserveTokenAmount);
        require(reserveToken.transferFrom(msg.sender, address(this), reserveTokenAmount), "Transfer failed");
        token.mint(msg.sender, tokenAmount);
    }
    
      
    function sellTokens(uint256 tokenAmount) public {
        require(tokenAmount > 0, "Amount must be greater than 0");
        uint256 reserveTokenAmount = calculateSaleReturn(tokenAmount);
        token.burn(msg.sender, tokenAmount);
        require(reserveToken.transfer(msg.sender, reserveTokenAmount), "Transfer failed");
    }

    function calculatePurchaseReturn(uint256 reserveTokenAmount) public view returns (uint256) {
        uint256 reserveBalance = reserveToken.balanceOf(address(this));
        uint256 supply = token.totalSupply();
                
        
        return (reserveTokenAmount * supply) / (reserveBalance * (1000000 / reserveWeight));
    }

    
    function calculateSaleReturn(uint256 tokenAmount) public view returns (uint256) {
        uint256 reserveBalance = reserveToken.balanceOf(address(this));
        uint256 supply = token.totalSupply();
        
        
        return (tokenAmount * reserveBalance) / (supply * (1000000 / reserveWeight));
    }

    function receiveReserveDeposit(uint256 amount) public {
        require(msg.sender == tokenFactory, "Only token factory can deposit reserve");
        require(reserveToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function setTokenFactory(address _tokenFactory) external  onlyOwner {
        tokenFactory = _tokenFactory;
    }
}