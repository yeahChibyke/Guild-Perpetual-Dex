// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IGuildToken} from "./interfaces/IGuildToken.sol";

contract GuildVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error GV__ZeroAddress();
    error GV__ZeroAmount();
    error GV__InvalidShares();
    error GV__InsufficientLiquidity();

    event GV__PerpSet(address indexed perp);
    event GV__Deposited(address indexed depositor, uint256 indexed deposit);
    event GV__Withdrew(address indexed withdrawer, uint256 indexed withdrawal);

    IERC20 immutable iAsset;
    IGuildToken immutable iToken;
    address perp;
    address admin;
    uint256 totalAssets;

    modifier notZeroAddress(address _addr) {
        if (_addr == address(0)) {
            revert GV__ZeroAddress();
        }
        _;
    }

    modifier notZeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert GV__ZeroAmount();
        }
        _;
    }

    modifier validShares(uint256 _shares) {
        if (_shares == 0 || _shares < iToken.balanceOf(msg.sender)) {
            revert GV__InvalidShares();
        }
        _;
    }

    constructor(address _asset, address _token, address _admin) {
        if (_asset == address(0) || _token == address(0) || _admin == address(0)) {
            revert GV__ZeroAddress();
        }

        iAsset = IERC20(_asset);
        iToken = IGuildToken(_token);
        admin = _admin;

        iToken.setVault(address(this));
    }

    function setPerp(address _perp) external notZeroAddress(_perp) {
        perp = _perp;
        iAsset.safeIncreaseAllowance(_perp, type(uint256).max); // --> thinking of adding onlyAdmin mod here... will it affect this line?

        emit GV__PerpSet(perp);
    }

    function deposit(uint256 _assetAmount) external notZeroAmount(_assetAmount) nonReentrant {
        uint256 sharesToReceive = convertToShares(_assetAmount);

        iAsset.safeTransferFrom(msg.sender, address(this), _assetAmount);

        // // supply liquidity to perp contract
        // perp.supplyLiquidity(); --> create interface so I can do IPerp(perp).supplyLiquidity();

        totalAssets += _assetAmount;

        iToken.mint(msg.sender, sharesToReceive);

        emit GV__Deposited(msg.sender, _assetAmount);
    }

    function withdraw(uint256 _sharesAmount) external validShares(_sharesAmount) nonReentrant {
        uint256 assetsToReceive = convertToAssets(_sharesAmount);

        if (assetsToReceive >= totalAssets) {
            revert GV__InsufficientLiquidity();
        }

        // // withdraw from perp if necessary
        // perp.exitLiquidity(); --> create interface so I can do IPerp(perp).exitLiquidity();

        totalAssets -= assetsToReceive;

        iToken.burn(msg.sender, _sharesAmount);

        iAsset.safeTransfer(msg.sender, assetsToReceive);

        emit GV__Withdrew(msg.sender, assetsToReceive);
    }

    function convertToShares(uint256 _assetAmount) public view notZeroAmount(_assetAmount) returns (uint256) {
        uint256 supply = iToken.totalSupply();

        uint256 sharesToReceive;

        if (supply == 0) {
            sharesToReceive = _assetAmount;
        } else {
            sharesToReceive = (_assetAmount * supply) / totalAssets;
        }

        return sharesToReceive;
    }

    function convertToAssets(uint256 _sharesAmount) public view notZeroAmount(_sharesAmount) returns (uint256) {
        uint256 supply = iToken.totalSupply();

        uint256 assetsToReceive;

        if (supply == 0) {
            assetsToReceive = _sharesAmount;
        } else {
            assetsToReceive = (_sharesAmount * totalAssets) / supply;
        }

        return assetsToReceive;
    }
}
