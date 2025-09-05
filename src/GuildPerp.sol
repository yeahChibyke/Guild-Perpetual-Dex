// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleChecker} from "./library/OracleChecker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GuildToken} from "./GuildToken.sol";
import {GuildVault} from "./GuildVault.sol";

contract GuildPerp is ReentrancyGuard, Ownable {
    // ------------------------------------------------------------------
    //                               TYPE
    // ------------------------------------------------------------------
    using SafeERC20 for IERC20;
    using OracleChecker for AggregatorV3Interface;

    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error GP__ZeroAddress();
    error GP__ZeroAmount();
    error GP__NotAllowed();
    error GP__SizeError();
    error GP__TradesNotAllowed();
    error GP__TradesCurrentlyActive();
    error GP__InsufficientLiquidity();
    error GP__LeverageTooLow();
    error GP__LeverageTooHigh();
    error GP__PositionAlreadyExists();
    error GP__NoPositionFound();
    error GP__InvalidCollateralAmount();

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event GP__PositionOpened(
        address indexed trader, uint256 collateralAmount, uint256 indexed size, bool indexed status, uint256 positionId
    );
    event GP__PositionClosed(address indexed trader, int256 pnl, uint256 feeAmount);
    event GP__BTCPriceUpdated(uint256 indexed newRate);
    event GP__TradingFeeCollected(address indexed trader, uint256 feeAmount, uint256 minutesOpen);
    event GP__TradingAllowedToggled(bool newStatus);
    event GP__TradingFeeUpdated(uint256 newFee);

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    IERC20 immutable iUSD; // collateral token (USDC - 6 decimals)
    IERC20 immutable iBTC; // traded token (BTC - 8 decimals)

    GuildToken immutable gToken;
    GuildVault immutable gVault;

    // Constants with proper precision
    uint256 constant MIN_LEVERAGE = 2 * 1e18; // 2x leverage with 18 decimals precision
    uint256 constant MAX_LEVERAGE = 20 * 1e18; // 20x leverage with 18 decimals precision
    uint256 constant MIN_COLLATERAL = 10_000e6; // $10,000 USDC (6 decimals)
    uint256 constant MAX_COLLATERAL = 1_000_000e6; // $1,000,000 USDC (6 decimals)
    uint256 constant PRECISION = 1e18; // Standard 18 decimal precision
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10; // To convert Chainlink 8 decimals to 18 decimals
    uint256 constant FEE_PRECISION = 100000; // For fee calculations (0.001% = 1/100000)
    uint256 constant PRICE_PRECISION = 1e8; // BTC price precision (8 decimals from Chainlink)
    uint256 constant USD_PRECISION = 1e6; // USDC precision (6 decimals)
    uint256 constant SECONDS_PER_MINUTE = 60;

    address admin;
    bool allowed;

    uint256 totalLiquidity;
    uint256 tradingFeePerMinute = 1; // 0.001% per minute (1/100000)

    uint256 positionCounter;
    mapping(address trader => Position) positions;
    mapping(uint256 id => Position) positionsById;
    mapping(uint256 id => address trader) ownerOfPositionById;
    mapping(address => uint256) public positionOpenTime;
    mapping(uint256 => uint256) public positionOpenTimeById;
    mapping(address btc => address priceFeed) s_priceFeed;

    struct Position {
        uint256 collateralAmount; // USD collateral in 6 decimals (USDC)
        uint256 size; // Position size in USD with 6 decimals
        uint256 entryPrice; // BTC price at entry with 8 decimals
        uint256 leverage; // Leverage with 18 decimals precision
        bool status; // true for long, false for short
        bool exists; // Flag to check if position exists
    }

    // ------------------------------------------------------------------
    //                            MODIFIERS
    // ------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert GP__NotAllowed();
        }
        _;
    }

    modifier tradesAllowed() {
        if (allowed == false) {
            revert GP__TradesNotAllowed();
        }
        _;
    }

    modifier tradesPaused() {
        if (allowed == true) {
            revert GP__TradesCurrentlyActive();
        }
        _;
    }

    modifier onlyVault() {
        if (msg.sender != address(gVault)) {
            revert GP__NotAllowed();
        }
        _;
    }

    modifier notZeroAddress(address _addr) {
        if (_addr == address(0)) {
            revert GP__ZeroAddress();
        }
        _;
    }

    modifier validCollateral(uint256 _amount) {
        if (_amount < MIN_COLLATERAL || _amount > MAX_COLLATERAL) {
            revert GP__InvalidCollateralAmount();
        }
        _;
    }

    modifier positionExists(address _trader) {
        if (!positions[_trader].exists) {
            revert GP__NoPositionFound();
        }
        _;
    }

    modifier noPositionExists(address _trader) {
        if (positions[_trader].exists) {
            revert GP__PositionAlreadyExists();
        }
        _;
    }

    // ------------------------------------------------------------------
    //                           CONSTRUCTOR
    // ------------------------------------------------------------------
    constructor(
        address _collateralToken,
        address _tradedToken,
        address _token,
        address _btc_usd_pricefeed,
        address _vault,
        address _admin
    ) Ownable(_admin) {
        if (
            _collateralToken == address(0) || _tradedToken == address(0) || _token == address(0)
                || _btc_usd_pricefeed == address(0) || _vault == address(0) || _admin == address(0)
        ) {
            revert GP__ZeroAddress();
        }

        iUSD = IERC20(_collateralToken);
        iBTC = IERC20(_tradedToken);
        s_priceFeed[_tradedToken] = _btc_usd_pricefeed;
        gToken = GuildToken(_token);
        gVault = GuildVault(_vault);
        admin = _admin;
        allowed = true; // Enable trading by default
    }

    // ------------------------------------------------------------------
    //                   ONLYVAULT EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function supplyLiquidity(uint256 _amount) external onlyVault {
        if (_amount == 0) {
            revert GP__ZeroAmount();
        }
        totalLiquidity += _amount;
    }

    function exitLiquidity(uint256 _amount) external onlyVault {
        if (_amount == 0) {
            revert GP__ZeroAmount();
        }
        if (_amount > totalLiquidity) {
            revert GP__InsufficientLiquidity();
        }
        totalLiquidity -= _amount;
    }

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------

    function openPosition(uint256 _collateralAmount, uint256 _size, bool _status)
        external
        tradesAllowed
        nonReentrant
        noPositionExists(msg.sender)
        validCollateral(_collateralAmount)
        returns (uint256)
    {
        if (_size == 0) {
            revert GP__ZeroAmount();
        }

        // Calculate leverage with proper precision
        // leverage = (size * PRECISION) / collateralAmount
        uint256 positionLeverage = (_size * PRECISION) / _collateralAmount;
        
        // Check leverage bounds
        if (positionLeverage < MIN_LEVERAGE) {
            revert GP__LeverageTooLow();
        }
        if (positionLeverage > MAX_LEVERAGE) {
            revert GP__LeverageTooHigh();
        }

        // Check if vault has enough liquidity to cover potential losses
        uint256 maxPotentialLoss = _size; // Worst case: 100% loss of position size
        if (maxPotentialLoss > totalLiquidity) {
            revert GP__InsufficientLiquidity();
        }

        // Transfer collateral from trader
        iUSD.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        uint256 currentBTCPrice = getBTCPrice();

        Position memory newPosition = Position({
            collateralAmount: _collateralAmount,
            size: _size,
            entryPrice: currentBTCPrice,
            leverage: positionLeverage,
            status: _status,
            exists: true
        });

        // Generate new position ID
        uint256 positionId = positionCounter++;

        // Update mappings
        positions[msg.sender] = newPosition;
        positionsById[positionId] = newPosition;
        ownerOfPositionById[positionId] = msg.sender;

        uint256 currentTime = block.timestamp;
        positionOpenTime[msg.sender] = currentTime;
        positionOpenTimeById[positionId] = currentTime;

        emit GP__PositionOpened(msg.sender, _collateralAmount, _size, _status, positionId);

        return positionId;
    }

    function closePosition() external tradesAllowed nonReentrant positionExists(msg.sender) {
        Position memory position = positions[msg.sender];

        // Calculate PnL with proper precision
        int256 pnl = calculatePnL(msg.sender);
        uint256 positionValue = position.collateralAmount;

        // Apply PnL to position value
        if (pnl > 0) {
            positionValue += uint256(pnl);
        } else if (pnl < 0) {
            uint256 loss = uint256(-pnl);
            if (loss >= positionValue) {
                positionValue = 0; // Complete loss (liquidation)
            } else {
                positionValue -= loss;
            }
        }

        // Calculate trading fee based on time
        uint256 openTime = positionOpenTime[msg.sender];
        uint256 timeOpen = block.timestamp - openTime;
        uint256 minutesOpen = timeOpen / SECONDS_PER_MINUTE;

        // Calculate fee: (positionValue * tradingFeePerMinute * minutesOpen) / FEE_PRECISION
        uint256 feeAmount = (positionValue * tradingFeePerMinute * minutesOpen) / FEE_PRECISION;

        // Ensure fee doesn't exceed position value
        if (feeAmount > positionValue) {
            feeAmount = positionValue;
        }

        uint256 amountToReturn = positionValue - feeAmount;

        // Update vault liquidity based on PnL
        if (pnl > 0) {
            // Trader profit = vault loss
            if (uint256(pnl) > totalLiquidity) {
                totalLiquidity = 0;
            } else {
                totalLiquidity -= uint256(pnl);
            }
        } else if (pnl < 0) {
            // Trader loss = vault gain (minus fees)
            totalLiquidity += uint256(-pnl);
        }

        // Transfer fee to vault if any
        if (feeAmount > 0) {
            iUSD.safeTransfer(address(gVault), feeAmount);
            totalLiquidity += feeAmount; // Fees go to vault liquidity
        }

        // Transfer remaining amount to trader if any
        if (amountToReturn > 0) {
            iUSD.safeTransfer(msg.sender, amountToReturn);
        }

        // Clear position data
        delete positions[msg.sender];
        delete positionOpenTime[msg.sender];

        emit GP__PositionClosed(msg.sender, pnl, feeAmount);
        emit GP__TradingFeeCollected(msg.sender, feeAmount, minutesOpen);
    }

    // ------------------------------------------------------------------
    //                      ADMIN FUNCTIONS
    // ------------------------------------------------------------------

    function toggleTrading() external onlyAdmin {
        allowed = !allowed;
        emit GP__TradingAllowedToggled(allowed);
    }

    function setTradingFeePerMinute(uint256 _newFee) external onlyAdmin {
        require(_newFee <= 100, "Fee too high"); // Max 0.1% per minute
        tradingFeePerMinute = _newFee;
        emit GP__TradingFeeUpdated(_newFee);
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyAdmin {
        IERC20(_token).safeTransfer(admin, _amount);
    }

    // ------------------------------------------------------------------
    //                      PUBLIC VIEW FUNCTIONS
    // ------------------------------------------------------------------

    function getBTCPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[address(iBTC)]);
        (, int256 answer,,,) = priceFeed.staleDataCheck();
        
        // Convert Chainlink price (8 decimals) to our standard (8 decimals for BTC price)
        return uint256(answer);
    }

    function calculatePnL(address _trader) public view notZeroAddress(_trader) returns (int256) {
        Position memory position = positions[_trader];
        
        if (!position.exists) {
            return 0;
        }

        uint256 currentBTCPrice = getBTCPrice();
        uint256 entryPrice = position.entryPrice;
        uint256 positionSize = position.size;

        // Calculate PnL with proper precision
        // For long positions: PnL = (currentPrice - entryPrice) * (positionSize / entryPrice)
        // For short positions: PnL = (entryPrice - currentPrice) * (positionSize / entryPrice)
        
        int256 priceDiff;
        if (position.status) { // Long position
            priceDiff = int256(currentBTCPrice) - int256(entryPrice);
        } else { // Short position
            priceDiff = int256(entryPrice) - int256(currentBTCPrice);
        }

        // PnL = (priceDiff * positionSize) / entryPrice
        // All calculations maintain proper decimal precision
        int256 pnl = (priceDiff * int256(positionSize)) / int256(entryPrice);

        return pnl;
    }

    function getPositionById(uint256 _id) external view returns (Position memory) {
        return positionsById[_id];
    }

    function getOwnerOfPosition(uint256 _id) external view returns (address) {
        address owner = ownerOfPositionById[_id];
        require(owner != address(0), "Position does not exist");
        return owner;
    }

    function getTradingFeePerMinute() external view returns (uint256) {
        return tradingFeePerMinute;
    }

    function getPositionDuration(address _trader) external view returns (uint256) {
        if (positionOpenTime[_trader] == 0) {
            return 0;
        }
        return block.timestamp - positionOpenTime[_trader];
    }

    function getTotalLiquidity() external view returns (uint256) {
        return totalLiquidity;
    }

    function isTradingAllowed() external view returns (bool) {
        return allowed;
    }

    function getPosition(address _trader) external view returns (Position memory) {
        return positions[_trader];
    }

    function hasPosition(address _trader) external view returns (bool) {
        return positions[_trader].exists;
    }

    // Calculate liquidation price for a position
    function getLiquidationPrice(address _trader) external view returns (uint256) {
        Position memory position = positions[_trader];
        
        if (!position.exists) {
            return 0;
        }

        // Liquidation occurs when losses equal the collateral
        // For long: liquidationPrice = entryPrice * (1 - collateral/size)
        // For short: liquidationPrice = entryPrice * (1 + collateral/size)
        
        uint256 collateralRatio = (position.collateralAmount * PRICE_PRECISION) / position.size;
        
        if (position.status) { // Long position
            if (collateralRatio >= PRICE_PRECISION) {
                return 0; // Cannot be liquidated
            }
            return (position.entryPrice * (PRICE_PRECISION - collateralRatio)) / PRICE_PRECISION;
        } else { // Short position
            return (position.entryPrice * (PRICE_PRECISION + collateralRatio)) / PRICE_PRECISION;
        }
    }
}