// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GuildToken} from "../../src/GuildToken.sol";
import {GuildVault} from "../../src/GuildVault.sol";
import {GuildPerp} from "../../src/GuildPerp.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestGT is Test {
    GuildToken gtoken;
    GuildVault gvault;
    GuildPerp gperp;
    ERC20Mock usdc;
    ERC20Mock wbtc;
    address pricefeed;

    address admin;

    function setUp() public {
        admin = makeAddr("admin");
        pricefeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

        usdc = new ERC20Mock();
        wbtc = new ERC20Mock();

        gtoken = new GuildToken(admin);
        gvault = new GuildVault(address(usdc), address(gtoken), admin);
        gperp = new GuildPerp(address(usdc), address(wbtc), address(gtoken), pricefeed, address(gvault), admin);
    }

    function test_feed() public view {
        console2.log(gperp.getBTCPrice());
    }
}
