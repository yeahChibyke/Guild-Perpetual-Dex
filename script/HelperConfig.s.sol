// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract CodeConstants {
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 100000e8;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address priceFeed;
        address wBtc;
        address usdc;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chaindId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaBTCConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].priceFeed != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilBTCConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaBTCConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        });
    }

    function getOrCreateAnvilBTCConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.priceFeed != address(0)) {
            return localNetworkConfig;
        }

        console2.log(unicode"⚠️ You have deployed a mock contract!");
        console2.log("Make sure this was intentional");

        vm.startBroadcast();

        MockV3Aggregator priceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        ERC20Mock wbtc = new ERC20Mock();
        ERC20Mock usd = new ERC20Mock();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({priceFeed: address(priceFeed), wBtc: address(wbtc), usdc: address(usd)});
        return localNetworkConfig;
    }
}
