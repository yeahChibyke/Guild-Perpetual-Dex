// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGuildToken} from "./interfaces/IGuildToken.sol";
import {IGuildVault} from "./interfaces/IGuildVault.sol";

contract GuildPerp is ReentrancyGuard, Ownable {
    error GP__ZeroAddress();
    error GP__ZeroAmount();
    error GP__SizeNotSet();
    error GP__NotAllowed();
    error GP__SizeError();
    error GP__TradesNotAllowed();
    error GP__InsufficientLiquidity();

    IERC20 iUSD; // collateral token
    IERC20 iBTC; // traded token

    IGuildToken gToken;
    IGuildVault gVault;

    address admin;

    struct Position {
        uint256 size;
        uint256 collateralAmount;
        bool status; // true for long. false for short
        uint256 entryPrice;
    }

    mapping(address trader => Position) positions;

    uint256 minSize;
    uint256 maxSize;
    uint256 totalLiquidity;

    uint256 constant AT_MIN_SIZE = 1; // all time min size
    uint256 constant AT_MAX_SIZE = 20; // all time max size

    bool allowed;

    event GP__PositionOpened(
        address indexed trader, uint256 collateralAmount, uint256 indexed size, bool indexed status
    );
    event GP__PositionClosed(address indexed trader);
    event GP__SizeSet(uint256 indexed minSize, uint256 indexed maxSize);

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

    function setSize(uint256 _minSize, uint256 _maxSize) external onlyAdmin returns (bool) {
        require(allowed == false, "Pause trades before resetting size!!!");

        if (_minSize == 0 || _maxSize == 0) {
            revert GP__ZeroAmount();
        }

        if (_minSize >= _maxSize || _minSize == AT_MIN_SIZE || _maxSize > AT_MAX_SIZE) {
            revert GP__SizeError();
        }

        minSize = _minSize;
        maxSize = _maxSize;

        emit GP__SizeSet(minSize, maxSize);

        return true;
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
}
