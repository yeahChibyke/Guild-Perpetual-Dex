// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GuildPerpetualDex is Ownable {
    using SafeERC20 for IERC20;

    error GPD__ZeroAddress();
    error GPD__ZeroAmount();
    error GPD__NotAllowed();

    IERC20 usd;
    IERC20 btc;

    address admin;

    bool initialized;

    uint256 pool;
    uint256 minSize;
    uint256 maxSize;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert GPD__NotAllowed();
        }
        _;
    }

    constructor(address _admin, address _collateral, address _asset) Ownable(_admin) {
        if (_admin == address(0) || _collateral == address(0) || _asset == address(0)) {
            revert GPD__ZeroAddress();
        }

        admin = _admin;
        usd = IERC20(_collateral);
        btc = IERC20(_asset);
    }

    function initialize(uint256 _amount, uint256 _minSize, uint256 _maxSize) external onlyAdmin returns (bool) {
        usd.safeTransferFrom(msg.sender, address(this), _amount);

        if (_minSize == 0 || _maxSize == 0) {
            revert GPD__ZeroAmount();
        }

        if (_minSize >= _maxSize) {
            revert GPD__NotAllowed();
        }

        minSize = _minSize;
        maxSize = _maxSize;

        initialized = true;
        return initialized;
    }

    function getCollateral() external view returns (address) {
        return address(usd);
    }

    function getAsset() external view returns (address) {
        return address(btc);
    }

    function getPool() external returns (uint256) {
        pool = usd.balanceOf(address(this));
        return pool;
    }

    function getMinSize() external view returns (uint256) {
        return minSize;
    }

    function getMaxSize() external view returns (uint256) {
        return maxSize;
    }
}
