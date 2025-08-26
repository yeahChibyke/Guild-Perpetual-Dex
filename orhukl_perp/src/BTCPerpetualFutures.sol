// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BTCPerpetualFutures
 * @dev A simplified perpetual futures contract for Bitcoin trading
 * @notice This is a mock contract for educational purposes only
 */
contract BTCPerpetualFutures is Ownable, ReentrancyGuard {
    
    // Position struct to track user positions
    struct Position {
        uint256 size;           // Position size in USD
        uint256 entryPrice;     // Entry price in USD (scaled by 1e8)
        uint256 collateral;     // Collateral amount in USD
        bool isLong;           // True for long, false for short
        uint256 timestamp;     // Position open timestamp
        bool isOpen;           // Position status
    }
    
    // State variables
    IERC20 public collateralToken; // USDC or similar stablecoin
    uint256 public currentBTCPrice; // Current BTC price (scaled by 1e8)
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% (scaled by 100)
    uint256 public constant MAX_LEVERAGE = 10; // 10x leverage
    uint256 public constant PRICE_SCALE = 1e8;
    uint256 public constant PERCENT_SCALE = 10000;
    
    // Mappings
    mapping(address => Position) public positions;
    mapping(address => uint256) public userCollateral;
    
    // Events
    event PositionOpened(address indexed user, bool isLong, uint256 size, uint256 entryPrice, uint256 collateral);
    event PositionClosed(address indexed user, uint256 exitPrice, int256 pnl);
    event PositionLiquidated(address indexed user, address indexed liquidator, uint256 liquidationPrice);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PriceUpdated(uint256 newPrice);
    
    constructor(address _collateralToken, uint256 _initialBTCPrice, address _initialOwner) Ownable(_initialOwner) {
        collateralToken = IERC20(_collateralToken);
        currentBTCPrice = _initialBTCPrice * PRICE_SCALE; // Scale the price
    }
    
    /**
     * @dev Update BTC price (in real implementation, this would use an oracle)
     * @param _newPrice New BTC price in USD
     */
    function updateBTCPrice(uint256 _newPrice) external onlyOwner {
        currentBTCPrice = _newPrice * PRICE_SCALE;
        emit PriceUpdated(currentBTCPrice);
    }
    
    /**
     * @dev Deposit collateral to the contract
     * @param _amount Amount of collateral to deposit
     */
    function depositCollateral(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(collateralToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        userCollateral[msg.sender] += _amount;
        emit CollateralDeposited(msg.sender, _amount);
    }
    
    /**
     * @dev Withdraw collateral from the contract
     * @param _amount Amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(userCollateral[msg.sender] >= _amount, "Insufficient collateral");
        require(!positions[msg.sender].isOpen, "Cannot withdraw with open position");
        
        userCollateral[msg.sender] -= _amount;
        require(collateralToken.transfer(msg.sender, _amount), "Transfer failed");
        
        emit CollateralWithdrawn(msg.sender, _amount);
    }
    
    /**
     * @dev Open a long position on BTC
     * @param _size Position size in USD
     * @param _collateralAmount Collateral amount to use
     */
    function longBTC(uint256 _size, uint256 _collateralAmount) external nonReentrant {
        require(!positions[msg.sender].isOpen, "Position already exists");
        require(_size > 0, "Size must be greater than 0");
        require(_collateralAmount > 0, "Collateral must be greater than 0");
        require(userCollateral[msg.sender] >= _collateralAmount, "Insufficient collateral");
        require(_size <= _collateralAmount * MAX_LEVERAGE, "Exceeds max leverage");
        
        // Create position
        positions[msg.sender] = Position({
            size: _size,
            entryPrice: currentBTCPrice,
            collateral: _collateralAmount,
            isLong: true,
            timestamp: block.timestamp,
            isOpen: true
        });
        
        // Lock collateral
        userCollateral[msg.sender] -= _collateralAmount;
        
        emit PositionOpened(msg.sender, true, _size, currentBTCPrice, _collateralAmount);
    }
    
    /**
     * @dev Open a short position on BTC
     * @param _size Position size in USD
     * @param _collateralAmount Collateral amount to use
     */
    function shortBTC(uint256 _size, uint256 _collateralAmount) external nonReentrant {
        require(!positions[msg.sender].isOpen, "Position already exists");
        require(_size > 0, "Size must be greater than 0");
        require(_collateralAmount > 0, "Collateral must be greater than 0");
        require(userCollateral[msg.sender] >= _collateralAmount, "Insufficient collateral");
        require(_size <= _collateralAmount * MAX_LEVERAGE, "Exceeds max leverage");
        
        // Create position
        positions[msg.sender] = Position({
            size: _size,
            entryPrice: currentBTCPrice,
            collateral: _collateralAmount,
            isLong: false,
            timestamp: block.timestamp,
            isOpen: true
        });
        
        // Lock collateral
        userCollateral[msg.sender] -= _collateralAmount;
        
        emit PositionOpened(msg.sender, false, _size, currentBTCPrice, _collateralAmount);
    }
    
    /**
     * @dev Close an existing position
     */
    function closePosition() external nonReentrant {
        Position storage position = positions[msg.sender];
        require(position.isOpen, "No open position");
        
        // Calculate P&L
        int256 pnl = calculatePnL(msg.sender);
        uint256 exitPrice = currentBTCPrice;
        
        // Close position
        position.isOpen = false;
        
        // Return collateral + P&L
        uint256 returnAmount = position.collateral;
        if (pnl >= 0) {
            returnAmount += uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= returnAmount) {
                returnAmount = 0; // Total loss
            } else {
                returnAmount -= loss;
            }
        }
        
        if (returnAmount > 0) {
            userCollateral[msg.sender] += returnAmount;
        }
        
        emit PositionClosed(msg.sender, exitPrice, pnl);
    }
    
    /**
     * @dev Liquidate a user's position (admin only)
     * @param _user Address of the user to liquidate
     */
    function liquidateUser(address _user) external onlyOwner nonReentrant {
        Position storage position = positions[_user];
        require(position.isOpen, "No open position");
        require(isLiquidatable(_user), "Position not liquidatable");
        
        // Close position
        position.isOpen = false;
        
        // In a real implementation, liquidation might give some remaining collateral to user
        // and liquidation rewards to the liquidator
        
        emit PositionLiquidated(_user, msg.sender, currentBTCPrice);
    }
    
    /**
     * @dev Calculate profit and loss for a position
     * @param _user Address of the user
     * @return pnl Profit and loss amount (can be negative)
     */
    function calculatePnL(address _user) public view returns (int256 pnl) {
        Position memory position = positions[_user];
        if (!position.isOpen) return 0;
        
        if (position.isLong) {
            // Long P&L = (current_price - entry_price) / entry_price * position_size
            int256 priceDiff = int256(currentBTCPrice) - int256(position.entryPrice);
            pnl = (priceDiff * int256(position.size)) / int256(position.entryPrice);
        } else {
            // Short P&L = (entry_price - current_price) / entry_price * position_size
            int256 priceDiff = int256(position.entryPrice) - int256(currentBTCPrice);
            pnl = (priceDiff * int256(position.size)) / int256(position.entryPrice);
        }
    }
    
    /**
     * @dev Check if a position can be liquidated
     * @param _user Address of the user
     * @return bool True if position can be liquidated
     */
    function isLiquidatable(address _user) public view returns (bool) {
        Position memory position = positions[_user];
        if (!position.isOpen) return false;
        
        int256 pnl = calculatePnL(_user);
        int256 currentValue = int256(position.collateral) + pnl;
        
        // Liquidate if current value is less than 80% of original collateral
        int256 liquidationThreshold = int256(position.collateral * LIQUIDATION_THRESHOLD / PERCENT_SCALE);
        
        return currentValue <= liquidationThreshold;
    }
    
    /**
     * @dev Get position details for a user
     * @param _user Address of the user
     * @return position Position struct
     */
    function getPosition(address _user) external view returns (Position memory) {
        return positions[_user];
    }
    
    /**
     * @dev Get current position value including P&L
     * @param _user Address of the user
     * @return currentValue Current position value
     */
    function getCurrentPositionValue(address _user) external view returns (int256 currentValue) {
        Position memory position = positions[_user];
        if (!position.isOpen) return 0;
        
        int256 pnl = calculatePnL(_user);
        currentValue = int256(position.collateral) + pnl;
    }
    
    /**
     * @dev Emergency function to pause trading (if needed)
     */
    function emergencyStop() external onlyOwner {
        // In a real implementation, this might pause all trading functions
        // This is just a placeholder for emergency controls
    }
}