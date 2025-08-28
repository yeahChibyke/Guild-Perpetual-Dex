// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IGuildToken} from "./interfaces/IGuildToken.sol";
import {IGuildVault} from "./interfaces/IGuildVault.sol";

contract GuildPerp is ReentrancyGuard {}
