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

    address alice;
    address bob;
    address clara;

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

        vm.startPrank(admin);
        gtoken.setVault(address(gvault));
        gvault.setPerp(address(gperp));
        vm.stopPrank();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        clara = makeAddr("clara");

        usdc.mint(alice, 100_000e6);
        usdc.mint(bob, 50_000e6);
        usdc.mint(clara, 10_000e6);
    }

    function test_gtoken_get_admin() public view {
        assert(gtoken.getAdmin() == admin);
    }

    function test_gtoken_get_vault() public view {
        assert(gtoken.getVault() == address(gvault));
    }

    function test_gvault_deposit() public {
        vm.startPrank(alice);
        usdc.approve(address(gvault), 100_000e6);
        gvault.deposit(100_000e6);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(gvault), 100_000e6);
        gvault.deposit(50_000e6);
        vm.stopPrank();

        console2.log(gtoken.balanceOf(alice));
        console2.log(gtoken.balanceOf(bob));
        console2.log(gtoken.getTotalSupply());
    }

    function test_get_price() public view {
        console2.log(gperp.getBTCPrice());
    }
}
