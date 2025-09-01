// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GuildPerp} from "../src/GuildPerp.sol";
import {IGuildToken} from "../src/interfaces/IGuildToken.sol";
import {IGuildVault} from "../src/interfaces/IGuildVault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
// import {MockWBTC} from "../test/mocks/MockWBTC.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

contract DeployGuildPerp is Script {
    GuildPerp gPerp;
    HelperConfig config;
    // MockWBTC wbtc;
    MockUSDC usdc;

    address token = makeAddr("Guild Token");
    address vault = makeAddr("Guild Vault");
    address admin = makeAddr("Admin");

    function run() external {
        usdc = new MockUSDC(6);

        config = new HelperConfig();
        (address btcUsdPriceFeed, address wbtc, uint256 deployerKey) = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        gPerp = new GuildPerp(address(usdc), wbtc, token, btcUsdPriceFeed, vault, admin);
        vm.stopBroadcast();
    }
}
