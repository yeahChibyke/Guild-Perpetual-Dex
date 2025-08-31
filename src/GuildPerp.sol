// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGuildToken} from "./interfaces/IGuildToken.sol";
import {IGuildVault} from "./interfaces/IGuildVault.sol";

contract GuildPerp is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    error GP__ZeroAddress();
    error GP__ZeroAmount();
    error GP__NotAllowed();
    error GP__SizeError();
    error GP__TradesNotAllowed();
    error GP__TradesCurrentlyActive();
    error GP__InsufficientLiquidity();

    event GP__PositionOpened(
        address indexed trader, uint256 collateralAmount, uint256 indexed size, bool indexed status
    );
    event GP__PositionClosed(address indexed trader);
    event GP__BTCRateUpdated(uint256 indexed newRate);

    IERC20 immutable iUSD; // collateral token
    IERC20 immutable iBTC; // traded token

    IGuildToken immutable gToken;
    IGuildVault immutable gVault;

    uint256 constant MIN_SIZE = 2;
    uint256 constant MAX_SIZE = 20;
    uint256 constant MIN_COLLATERAL = 10_000e6;
    uint256 constant MAX_COLLATERAL = 1_000_000e6;

    address admin;

    bool allowed;

    uint256 totalLiquidity;
    uint256 btcRate;
    uint256 USD_PREC = 1e6;
    uint256 BTC_PREC = 1e8;

    mapping(address trader => Position) positions;

    struct Position {
        uint256 collateralAmount;
        uint256 size;
        uint256 entryPrice;
        bool status; // true for long. false for short
    }

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

    function updateBTCRate(uint256 _newRate) external onlyAdmin tradesPaused {
        btcRate = (_newRate * BTC_PREC);

        emit GP__BTCRateUpdated(btcRate);
    }

    function supplyLiquidity(uint256 _amount) external onlyVault {
        totalLiquidity += _amount;
    }

    function exitLiquidity(uint256 _amount) external onlyVault {
        if (_amount >= totalLiquidity) {
            revert GP__InsufficientLiquidity();
        }

        totalLiquidity -= _amount;
    }

    function openPosition(uint256 _collateralAmount, uint256 _size, bool _status) external tradesAllowed nonReentrant {
        if (_collateralAmount == 0 || _size == 0) {
            revert GP__ZeroAmount();
        }

        if (_collateralAmount < MIN_COLLATERAL || _collateralAmount > MAX_SIZE || _size < MIN_SIZE || _size > MAX_SIZE)
        {
            revert GP__NotAllowed();
        }

        iUSD.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        positions[msg.sender] =
            Position({collateralAmount: _collateralAmount, size: _size, entryPrice: getBTCRate(), status: _status});
    }

    function getBTCRate() public view returns (uint256) {
        return btcRate;
    }
}
