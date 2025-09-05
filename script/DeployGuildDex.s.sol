// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GuildPerp} from "../src/GuildPerp.sol";
import {GuildToken} from "../src/GuildToken.sol";
import {GuildVault} from "../src/GuildVault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployGuildDex is Script {
    GuildPerp gperp;
    GuildToken gtoken;
    GuildVault gvault;
    HelperConfig config;
    ERC20Mock usdc;
    ERC20Mock wbtc;

    address admin;
    address priceFeed;
    address usdcAddr;
    address wbtcAddr;

    function run() external returns (GuildToken, GuildVault, GuildPerp, HelperConfig) {
        return deployPerp();
    }

    function deployPerp() public returns (GuildToken, GuildVault, GuildPerp, HelperConfig) {
        admin = makeAddr("Admin");
        config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfigByChainId(block.chainid);
        priceFeed = networkConfig.priceFeed;
        usdcAddr = networkConfig.usdc;
        wbtcAddr = networkConfig.wBtc;

        usdc = ERC20Mock(usdcAddr);
        wbtc = ERC20Mock(wbtcAddr);

        vm.startBroadcast();
        gtoken = new GuildToken(admin);
        gvault = new GuildVault(address(usdc), address(gtoken), admin);
        gperp = new GuildPerp(address(usdc), address(wbtc), address(gtoken), priceFeed, address(gvault), admin);
        vm.stopBroadcast();

        return (gtoken, gvault, gperp, config);
    }

    function getUsdc() external view returns (ERC20Mock) {
        return usdc;
    }

    function getWbtc() external view returns (ERC20Mock) {
        return wbtc;
    }

    function getAdmin() external view returns (address) {
        return admin;
    }

    function getPriceFeed() external view returns (address) {
        return priceFeed;
    }
}
