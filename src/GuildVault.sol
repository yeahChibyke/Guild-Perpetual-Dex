// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GuildToken} from "./GuildToken.sol";

contract GuildVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error GV__ZeroAddress();
    error GV__ZeroAmount();

    event GV__PerpSet(address indexed perp);

    IERC20 immutable iAsset;
    GuildToken immutable iToken;
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

    constructor(address _asset, address _token, address _admin) {
        if (_asset == address(0) || _token == address(0) || _admin == address(0)) {
            revert GV__ZeroAddress();
        }

        iAsset = IERC20(_asset);
        iToken = GuildToken(_token);
        admin = _admin;

        iToken.setVault(address(this));
    }

    function setPerp(address _perp) external notZeroAddress(_perp) {
        perp = _perp;

        emit GV__PerpSet(perp);
    }

    function deposit() external nonReentrant {}

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
}
