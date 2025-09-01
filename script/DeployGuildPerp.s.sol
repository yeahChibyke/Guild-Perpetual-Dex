// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GuildPerp} from "../src/GuildPerp.sol";
import {GuildToken} from "../src/GuildToken.sol";
import {GuildVault} from "../src/GuildVault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

contract DeployGuildPerp is Script {
    GuildPerp gPerp;
    GuildToken gToken;
    GuildVault gVault;
    HelperConfig config;
    MockUSDC usdc;

    address token = makeAddr("Guild Token");
    address vault = makeAddr("Guild Vault");
    address admin = makeAddr("Admin");

    function run() external returns (GuildPerp, GuildToken, GuildVault) {
        usdc = new MockUSDC(6);

        config = new HelperConfig();
        (address btcUsdPriceFeed, address wbtc, uint256 deployerKey) = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        gPerp = new GuildPerp(address(usdc), wbtc, token, btcUsdPriceFeed, vault, admin);
        gToken = new GuildToken(admin);
        gVault = new GuildVault(address(usdc), address(gToken), admin);
        vm.stopBroadcast();

        return (gPerp, gToken, gVault);
    }
}
