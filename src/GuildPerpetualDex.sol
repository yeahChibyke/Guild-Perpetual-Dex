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

    IERC20 iusdc;
    IERC20 ibtc;

    address admin;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert GPD__NotAllowed();
        }
        _;
    }

    constructor(address _admin, address _collateral, address _asset, uint256 _amount) Ownable(_admin) {
        if (_admin == address(0) || _collateral == address(0) || _asset == address(0)) {
            revert GPD__ZeroAddress();
        }

        if (_amount == 0) {
            revert GPD__ZeroAmount();
        }

        admin = _admin;
        iusdc = IERC20(_collateral);
        ibtc = IERC20(_asset);

        _initializePool(_amount);
    }

    function _initializePool(uint256 _amount) internal {
        iusdc.safeTransferFrom(msg.sender, address(this), _amount);
    }
}
