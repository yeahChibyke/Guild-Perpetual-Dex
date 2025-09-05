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

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event GP__PositionOpened(
        address indexed trader, uint256 collateralAmount, uint256 indexed size, bool indexed status, uint256 positionId
    );
    event GP__PositionClosed(address indexed trader);
    event GP__BTCPriceUpdated(uint256 indexed newRate);
    event GP__TradingFeeCollected(address indexed trader, uint256 feeAmount, uint256 minutesOpen);

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    IERC20 immutable iUSD; // collateral token
    IERC20 immutable iBTC; // traded token

    GuildToken immutable gToken;
    GuildVault immutable gVault;

    uint256 constant MIN_LEVERAGE = 2;
    uint256 constant MAX_LEVERAGE = 20;
    uint256 constant MIN_COLLATERAL = 10_000e6;
    uint256 constant MAX_COLLATERAL = 1_000_000e6;
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 constant FEE_PRECISION = 100000;

    address admin;

    bool allowed;

    uint256 totalLiquidity;
    uint256 USD_PREC = 1e6;
    uint256 BTC_PREC = 1e8;
    uint256 tradingFeePerMinute = 1; // 0.001% per minute

    uint256 positionCounter;
    mapping(address trader => Position) positions;
    mapping(uint256 id => Position) positionsById;
    mapping(uint256 id => address trader) ownerOfPositionById;
    mapping(address => uint256) public positionOpenTime;
    mapping(uint256 => uint256) public positionOpenTimeById;
    mapping(address btc => address priceFeed) s_priceFeed;

    struct Position {
        uint256 collateralAmount;
        uint256 size;
        uint256 entryPrice;
        uint256 leverage;
        bool status; // true for long. false for short
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
    }

    // ------------------------------------------------------------------
    //                   ONLYVAULT EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function supplyLiquidity(uint256 _amount) external onlyVault {
        totalLiquidity += _amount;
    }

    function exitLiquidity(uint256 _amount) external onlyVault {
        if (_amount >= totalLiquidity) {
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
        returns (uint256)
    {
        if (_collateralAmount == 0 || _size == 0) {
            revert GP__ZeroAmount();
        }

        uint256 position_leverage = _size / _collateralAmount;
        uint256 min_position_leverage = _size / MIN_COLLATERAL;
        uint256 max_position_leverage = _size / MAX_COLLATERAL;

        if (
            _collateralAmount < MIN_COLLATERAL || _collateralAmount > MAX_COLLATERAL
                || position_leverage < min_position_leverage || position_leverage > max_position_leverage
        ) {
            revert GP__NotAllowed();
        }

        iUSD.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        Position memory newPosition = Position({
            collateralAmount: _collateralAmount,
            size: _size,
            entryPrice: getBTCPrice(),
            leverage: position_leverage,
            status: _status
        });

        // generate new position id
        uint256 positionId = positionCounter++;

        // update mappings
        positions[msg.sender] = newPosition;
        positionsById[positionId] = newPosition;
        ownerOfPositionById[positionId] = msg.sender;

        uint256 currentTime = block.timestamp;
        positionOpenTime[msg.sender] = currentTime;
        positionOpenTimeById[positionId] = currentTime;

        emit GP__PositionOpened(msg.sender, _collateralAmount, _size, _status, positionId);

        return positionCounter;
    }

    function closePosition() external tradesAllowed nonReentrant {
        Position memory position = positions[msg.sender];

        // Check if position exists
        if (position.collateralAmount == 0) {
            revert GP__ZeroAmount();
        }

        // Calculate PnL
        int256 pnl = calculatePnL(msg.sender);
        uint256 positionValue = position.collateralAmount;

        // Apply PnL to position value
        if (pnl > 0) {
            positionValue += uint256(pnl);
        } else if (pnl < 0) {
            uint256 loss = uint256(-pnl);
            if (loss > positionValue) {
                positionValue = 0; // Complete loss
            } else {
                positionValue -= loss;
            }
        }

        // Calculate trading fee based on time
        uint256 openTime = positionOpenTime[msg.sender];
        uint256 timeOpen = block.timestamp - openTime;
        uint256 minutesOpen = timeOpen / 60; // Convert seconds to minutes

        // Calculate fee: (tradingFeePerMinute * minutesOpen) / FEE_PRECISION
        uint256 feeAmount = (positionValue * tradingFeePerMinute * minutesOpen) / FEE_PRECISION;

        // Ensure fee doesn't exceed position value
        if (feeAmount > positionValue) {
            feeAmount = positionValue;
        }

        uint256 amountToReturn = positionValue - feeAmount;

        // Transfer fee to vault and remaining to trader
        if (feeAmount > 0) {
            iUSD.safeTransfer(address(gVault), feeAmount);
        }

        if (amountToReturn > 0) {
            iUSD.safeTransfer(msg.sender, amountToReturn);
        }

        // Clear position data
        delete positions[msg.sender];
        delete positionOpenTime[msg.sender];

        emit GP__PositionClosed(msg.sender);
        emit GP__TradingFeeCollected(msg.sender, feeAmount, timeOpen);
    }

    // ------------------------------------------------------------------
    //                      PUBLIC VIEW FUNCTIONS
    // ------------------------------------------------------------------

    function getBTCPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[address(iBTC)]);
        (, int256 answer,,,) = priceFeed.staleDataCheck();
        // Most USD pairs have 8 decimals, so we will assume they all do
        // We want to have everything in terms of wei, so we add 10 zeros at the end
        return ((uint256(answer) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function calculatePnL(address _trader) public view notZeroAddress(_trader) returns (int256) {
        Position memory position = positions[_trader];

        uint256 currentBTCPrice = getBTCPrice();
        uint256 btcPriceAtEntry = position.entryPrice;
        uint256 positionSize = position.size;
        uint256 btcAmount = (positionSize * PRECISION) / btcPriceAtEntry;

        int256 pnl;

        if (position.status) {
            pnl = int256((currentBTCPrice - btcPriceAtEntry) * btcAmount);
        } else {
            pnl = int256((btcPriceAtEntry - currentBTCPrice) * btcAmount);
        }

        return pnl / int256(PRECISION);
    }

    function getPositionById(uint256 _id) external view returns (Position memory) {
        return positionsById[_id];
    }

    function getOwnerOfPosition(uint256 _id) external view returns (address) {
        address owner = ownerOfPositionById[_id];
        require(owner != address(0), "Position does not exist!!!");
        return owner;
    }

    function setTradingFeePerMinute(uint256 _newFee) external onlyAdmin {
        require(_newFee <= 100, "Fee too high"); // Max 0.1% per minute
        tradingFeePerMinute = _newFee;
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
}
