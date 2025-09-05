// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {DeployGuildDex} from "../../script/DeployGuildDex.s.sol";
import {GuildPerp} from "../../src/GuildPerp.sol";
import {GuildToken} from "../../src/GuildToken.sol";
import {GuildVault} from "../../src/GuildVault.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestGuildDex is Test {
    DeployGuildDex deployer;
    GuildPerp gperp;
    GuildToken gtoken;
    GuildVault gvault;
    HelperConfig config;
    ERC20Mock usdc;
    ERC20Mock wbtc;
    address admin;
    address priceFeed;

    function setUp() public {
        deployer = new DeployGuildDex();
        (gtoken, gvault, gperp, config) = deployer.deployPerp();
        usdc = deployer.getUsdc();
        wbtc = deployer.getWbtc();
        admin = deployer.getAdmin();
        priceFeed = deployer.getPriceFeed();

        gtoken = new GuildToken(admin);
        gvault = new GuildVault(address(usdc), address(gtoken), admin);
        gperp = new GuildPerp(address(usdc), address(wbtc), address(gtoken), priceFeed, address(gvault), admin);
    }

    function testStuff() public view {
        console2.log(gperp.getBTCPrice());
    }
}
