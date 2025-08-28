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

    uint256 INIT_LIQUIDITY = 1_000_000; // 1 million
    uint256 POOL;
    uint256 PREC_6 = 1 ** 6;
    // uint256 PREC_8 = 1 ** 8;

    function setUp() public {
        admin = makeAddr("admin");

        usdc = new MockUSDC(6);
        wbtc = new MockWBTC(8);

        usdc.mint(admin, INIT_LIQUIDITY); // 1 million usdc

        gpd = new GuildPerpetualDex(admin, address(usdc), address(wbtc));

        _initialize();

        POOL = usdc.balanceOf(address(gpd));
    }

    function test_setup() public {
        assert(POOL == (INIT_LIQUIDITY * PREC_6));
        assert(gpd.getPool() == POOL);
        assert(gpd.getMinSize() == 2);
        assert(gpd.getMaxSize() == 10);
    }

    function _initialize() internal {
        vm.startPrank(admin);
        usdc.approve(address(gpd), INIT_LIQUIDITY * PREC_6);
        gpd.initialize(INIT_LIQUIDITY * PREC_6, 2, 10);
        vm.stopPrank();
    }
}
