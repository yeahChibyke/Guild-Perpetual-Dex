// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GuildToken} from "./GuildToken.sol";
import {GuildPerp} from "./GuildPerp.sol";

contract GuildVault is ReentrancyGuard {
    // ------------------------------------------------------------------
    //                               TYPE
    // ------------------------------------------------------------------
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error GV__ZeroAddress();
    error GV__ZeroAmount();
    error GV__InvalidShares();
    error GV__InsufficientLiquidity();

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event GV__PerpSet(address indexed perp);
    event GV__Deposited(address indexed depositor, uint256 indexed deposit);
    event GV__Withdrew(address indexed withdrawer, uint256 indexed withdrawal);

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    IERC20 immutable iAsset;
    GuildToken immutable iToken;
    GuildPerp iPerp;

    address private s_admin;
    uint256 private s_totalAssets;

    // ------------------------------------------------------------------
    //                            MODIFIERS
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    //                           CONSTRUCTOR
    // ------------------------------------------------------------------
    constructor(address _asset, address _token, address _admin) {
        if (_asset == address(0) || _token == address(0) || _admin == address(0)) {
            revert GV__ZeroAddress();
        }

        iAsset = IERC20(_asset);
        iToken = GuildToken(_token);
        s_admin = _admin;

        // iToken.setVault(address(this));
    }

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function setPerp(address _perp) external notZeroAddress(_perp) {
        iPerp = GuildPerp(_perp);
        iAsset.safeIncreaseAllowance(_perp, type(uint256).max); // --> thinking of adding onlyAdmin mod here... will it affect this line?

        emit GV__PerpSet(address(iPerp));
    }

    function deposit(uint256 _assetAmount) external notZeroAmount(_assetAmount) nonReentrant {
        uint256 sharesToReceive = convertToShares(_assetAmount);

        iAsset.safeTransferFrom(msg.sender, address(this), _assetAmount);

        // supply liquidity to perp contract
        iPerp.supplyLiquidity(_assetAmount);

        s_totalAssets += _assetAmount;

        iToken.mint(msg.sender, sharesToReceive);

        emit GV__Deposited(msg.sender, _assetAmount);
    }

    function withdraw(uint256 _sharesAmount) external validShares(_sharesAmount) nonReentrant {
        uint256 assetsToReceive = convertToAssets(_sharesAmount);

        if (assetsToReceive >= s_totalAssets) {
            revert GV__InsufficientLiquidity();
        }

        // withdraw from perp if necessary
        iPerp.exitLiquidity(_sharesAmount);

        s_totalAssets -= assetsToReceive;

        iToken.burn(msg.sender, _sharesAmount);

        iAsset.safeTransfer(msg.sender, assetsToReceive);

        emit GV__Withdrew(msg.sender, assetsToReceive);
    }

    // ------------------------------------------------------------------
    //                      PUBLIC VIEW FUNCTIONS
    // ------------------------------------------------------------------
    function convertToShares(uint256 _assetAmount) public view notZeroAmount(_assetAmount) returns (uint256) {
        uint256 supply = iToken.totalSupply();

        uint256 sharesToReceive;

        if (supply == 0) {
            sharesToReceive = _assetAmount;
        } else {
            sharesToReceive = (_assetAmount * supply) / s_totalAssets;
        }

        return sharesToReceive;
    }

    function convertToAssets(uint256 _sharesAmount) public view notZeroAmount(_sharesAmount) returns (uint256) {
        uint256 supply = iToken.totalSupply();

        uint256 assetsToReceive;

        if (supply == 0) {
            assetsToReceive = _sharesAmount;
        } else {
            assetsToReceive = (_sharesAmount * s_totalAssets) / supply;
        }

        return assetsToReceive;
    }

    // ------------------------------------------------------------------
    //                         GETTER FUNCTIONS
    // ------------------------------------------------------------------

    function getPerp() external view returns (address) {
        return address(iPerp);
    }

    function getAdmin() external view returns (address) {
        return s_admin;
    }

    function getTotalAssets() external view returns (uint256) {
        return s_totalAssets;
    }
}
