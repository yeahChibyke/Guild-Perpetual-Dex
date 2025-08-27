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

    function initialize(uint256 _amount) external onlyAdmin returns (bool) {
        usd.safeTransferFrom(msg.sender, address(this), _amount);
        initialized = true;
        return initialized;
    }
}
