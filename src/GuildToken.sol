// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GuildToken is ERC20 {
    IERC20 iUSDC;

    constructor(address _usdc) ERC20("GuildToken", "GTK") {
        iUSDC = IERC20(_usdc);
    }

    function deposit(uint256 _amount) external {}
}
