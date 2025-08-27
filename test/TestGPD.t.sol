// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GuildPerpetualDex} from "../src/GuildPerpetualDex.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";

contract TestGPD is Test {
    GuildPerpetualDex gpd;
    MockUSDC usdc;
    MockWBTC wbtc;

    address admin;

    uint256 LIQUIDITY = 1_000_000; // 1 million

    function setUp() public {
        admin = makeAddr("admin");

        usdc = new MockUSDC(6);
        wbtc = new MockWBTC(8);

        usdc.mint(admin, LIQUIDITY); // 1 million usdc

        gpd = new GuildPerpetualDex(admin, address(usdc), address(wbtc));
    }

    function test_setup() public view {
        console2.log(usdc.balanceOf(address(gpd)));
    }
}
