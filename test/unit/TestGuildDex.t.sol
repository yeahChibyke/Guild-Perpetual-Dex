// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {DeployGuildDex} from "../../script/DeployGuildDex.s.sol";
import {GuildPerp} from "../../src/GuildPerp.sol";
import {GuildToken} from "../../src/GuildToken.sol";
import {GuildVault} from "../../src/GuildVault.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract TestGuildDex is Test {
    DeployGuildDex deployer;
    GuildPerp gPerp;
    GuildToken gToken;
    GuildVault gVault;
    HelperConfig helper;
    MockUSDC usdc;
    MockWBTC wbtc;

    address priceFeed;
    address btc;
    uint256 key;

    function setUp() public {
        deployer = new DeployGuildDex();
        (gPerp, gToken, gVault) = deployer.run();
        helper = deployer.config();
        (priceFeed, btc, key) = helper.activeNetworkConfig();

        usdc = new MockUSDC(6);
        wbtc = MockWBTC(btc);
    }

    function testStuff() public view {
        console2.log(gPerp.getBTCPrice());
    }
}
