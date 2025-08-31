// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGuildToken} from "./interfaces/IGuildToken.sol";
import {IGuildVault} from "./interfaces/IGuildVault.sol";

contract GuildPerp is ReentrancyGuard, Ownable {
    // ------------------------------------------------------------------
    //                               TYPE
    // ------------------------------------------------------------------
    using SafeERC20 for IERC20;

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

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    IERC20 immutable iUSD; // collateral token
    IERC20 immutable iBTC; // traded token

    IGuildToken immutable gToken;
    IGuildVault immutable gVault;

    uint256 constant MIN_LEVERAGE = 2;
    uint256 constant MAX_LEVERAGE = 20;
    uint256 constant MIN_COLLATERAL = 10_000e6;
    uint256 constant MAX_COLLATERAL = 1_000_000e6;
    uint256 constant PRECISION = 1e18;

    address admin;

    bool allowed;

    uint256 totalLiquidity;
    uint256 btcPrice;
    uint256 USD_PREC = 1e6;
    uint256 BTC_PREC = 1e8;

    uint256 positionCounter;
    mapping(address trader => Position) positions;
    mapping(uint256 id => Position) positionsById;
    mapping(uint256 id => address trader) ownerOfPositionById;

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
    constructor(address _collateralToken, address _tradedToken, address _token, address _vault, address _admin)
        Ownable(_admin)
    {
        if (
            _collateralToken == address(0) || _tradedToken == address(0) || _token == address(0) || _vault == address(0)
                || _admin == address(0)
        ) {
            revert GP__ZeroAddress();
        }

        iUSD = IERC20(_collateralToken);
        iBTC = IERC20(_tradedToken);
        gToken = IGuildToken(_token);
        gVault = IGuildVault(_vault);
        admin = _admin;
    }

    // ------------------------------------------------------------------
    //                   ONLYADMIN EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------

    function updateBTCRate(uint256 _newRate) external onlyAdmin tradesPaused {
        btcPrice = (_newRate * BTC_PREC);

        emit GP__BTCPriceUpdated(btcPrice);
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

    function openPosition(uint256 _collateralAmount, uint256 _size, bool _status) external tradesAllowed nonReentrant {
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

        emit GP__PositionOpened(msg.sender, _collateralAmount, _size, _status, positionId);
    }

    // ------------------------------------------------------------------
    //                      PUBLIC VIEW FUNCTIONS
    // ------------------------------------------------------------------
    function getBTCPrice() public view returns (uint256) {
        return btcPrice;
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
}
