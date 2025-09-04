// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address btcUsdPriceFeed;
        address wBtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant BTC_USD_MOCK_PRICE = 100_000e8;
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    // 1_115_511

    constructor() {
        if (block.chainid == 1_115_511) {
            activeNetworkConfig = getSepoliaBTCConfig();
        } else {
            activeNetworkConfig = getAnvilBTCConfig();
        }
    }

    function getSepoliaBTCConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            btcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilBTCConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // if (activeNetworkConfig.btcUsdPriceFeed != address(0)) {
        //     return activeNetworkConfig;
        // }

        vm.startBroadcast();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_MOCK_PRICE);
        ERC20Mock wbtc = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            btcUsdPriceFeed: address(btcUsdPriceFeed),
            wBtc: address(wbtc),
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
