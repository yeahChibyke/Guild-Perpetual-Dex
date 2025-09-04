// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GuildPerp} from "../src/GuildPerp.sol";
import {GuildToken} from "../src/GuildToken.sol";
import {GuildVault} from "../src/GuildVault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployGuildDex is Script {
    GuildPerp gPerp;
    GuildToken gToken;
    GuildVault gVault;
    HelperConfig public config;
    ERC20Mock usdc;

    address token = makeAddr("Guild Token");
    address vault = makeAddr("Guild Vault");
    address admin = makeAddr("Admin");

    function run() external returns (GuildPerp, GuildToken, GuildVault) {
        usdc = new ERC20Mock();

        config = new HelperConfig();
        (address btcUsdPriceFeed, address wbtc, uint256 deployerKey) = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        gPerp = new GuildPerp(address(usdc), wbtc, token, btcUsdPriceFeed, vault, admin);
        gToken = new GuildToken(admin);
        gVault = new GuildVault(address(usdc), address(gToken), admin);
        // gToken.transferOwnership(address(gVault));
        vm.stopBroadcast();

        return (gPerp, gToken, gVault);
    }
}
