// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {DeployGuildDex} from "../../script/DeployGuildDex.s.sol";
import {GuildPerp} from "../../src/GuildPerp.sol";
import {GuildToken} from "../../src/GuildToken.sol";
import {GuildVault} from "../../src/GuildVault.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

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
    MockV3Aggregator mockPriceFeed;

    address alice;
    address bob;
    address clara;

    // Test constants
    uint256 constant MIN_COLLATERAL = 10_000e6; // $10,000
    uint256 constant MAX_COLLATERAL = 1_000_000e6; // $1,000,000
    uint256 constant MIN_LEVERAGE = 2 * 1e18; // 2x
    uint256 constant MAX_LEVERAGE = 20 * 1e18; // 20x
    uint256 constant PRECISION = 1e18;

    function setUp() public {
        deployer = new DeployGuildDex();
        (gtoken, gvault, gperp, config) = deployer.deployPerp();
        usdc = deployer.getUsdc();
        wbtc = deployer.getWbtc();
        admin = deployer.getAdmin();
        priceFeed = deployer.getPriceFeed();

        // Create mock price feed for testing
        mockPriceFeed = new MockV3Aggregator(8, 90000e8); // $90,000 BTC price

        gtoken = new GuildToken(admin);
        gvault = new GuildVault(address(usdc), address(gtoken), admin);
        gperp =
            new GuildPerp(address(usdc), address(wbtc), address(gtoken), address(mockPriceFeed), address(gvault), admin);

        vm.startPrank(admin);
        gtoken.setVault(address(gvault));
        gvault.setPerp(address(gperp));
        vm.stopPrank();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        clara = makeAddr("clara");

        // Mint USDC to test users
        usdc.mint(alice, 2_000_000e6); // $2M
        usdc.mint(bob, 1_000_000e6); // $1M
        usdc.mint(clara, 500_000e6); // $500K

        // Add initial liquidity to the vault
        vm.startPrank(alice);
        usdc.approve(address(gvault), 500_000e6);
        gvault.deposit(500_000e6);
        vm.stopPrank();
    }

    function updatePriceFeedForTesting(int256 newPrice) internal {
        mockPriceFeed.updateAnswer(newPrice);
        // Update timestamp to avoid stale data error
        vm.warp(block.timestamp + 1);
    }

    // =============================================================
    //                      BASIC FUNCTIONALITY TESTS
    // =============================================================

    function test_gtoken_get_admin() public view {
        assertEq(gtoken.getAdmin(), admin);
    }

    function test_gtoken_get_vault() public view {
        assertEq(gtoken.getVault(), address(gvault));
    }

    function test_gvault_deposit() public {
        vm.startPrank(bob);
        usdc.approve(address(gvault), 50_000e6);
        gvault.deposit(50_000e6);
        vm.stopPrank();

        assertGt(gtoken.balanceOf(bob), 0);
        console2.log("Bob's gToken balance:", gtoken.balanceOf(bob));
        console2.log("Total gToken supply:", gtoken.getTotalSupply());
    }

    function test_get_btc_price() public view {
        uint256 price = gperp.getBTCPrice();
        assertGt(price, 0);
        console2.log("BTC Price:", price);
    }

    function test_trading_allowed_by_default() public view {
        assertTrue(gperp.isTradingAllowed());
    }

    // =============================================================
    //                      POSITION OPENING TESTS
    // =============================================================

    function test_open_long_position_success() public {
        uint256 collateral = 50_000e6; // $50,000 USDC
        uint256 size = 200_000e6; // $200,000 position size (4x leverage)
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        uint256 positionId = gperp.openPosition(collateral, size, isLong);

        // Verify position was created
        GuildPerp.Position memory position = gperp.getPosition(alice);
        assertEq(position.collateralAmount, collateral);
        assertEq(position.size, size);
        assertTrue(position.status); // Long position
        assertTrue(position.exists);
        assertEq(position.leverage, (size * PRECISION) / collateral); // 4x leverage

        // Verify position ID mapping
        assertEq(gperp.getOwnerOfPosition(positionId), alice);

        vm.stopPrank();

        console2.log("Position opened successfully with ID:", positionId);
        console2.log("Leverage:", position.leverage / 1e18, "x");
    }

    function test_open_short_position_success() public {
        uint256 collateral = 25_000e6; // $25,000 USDC
        uint256 size = 100_000e6; // $100,000 position size (4x leverage)
        bool isShort = false;

        vm.startPrank(bob);
        usdc.approve(address(gperp), collateral);

        uint256 positionId = gperp.openPosition(collateral, size, isShort);

        // Verify position was created
        GuildPerp.Position memory position = gperp.getPosition(bob);
        assertEq(position.collateralAmount, collateral);
        assertEq(position.size, size);
        assertFalse(position.status); // Short position
        assertTrue(position.exists);

        vm.stopPrank();

        console2.log("Short position opened with ID:", positionId);
    }

    function test_open_position_min_leverage() public {
        uint256 collateral = 100_000e6; // $100,000 USDC
        uint256 size = 200_000e6; // $200,000 position size (2x leverage - minimum)
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        uint256 positionId = gperp.openPosition(collateral, size, isLong);

        GuildPerp.Position memory position = gperp.getPosition(alice);
        assertEq(position.leverage, MIN_LEVERAGE);

        vm.stopPrank();

        console2.log("Minimum leverage position opened:", position.leverage / 1e18, "x");
    }

    function test_open_position_max_leverage() public {
        uint256 collateral = 50_000e6; // $50,000 USDC
        uint256 size = 1_000_000e6; // $1,000,000 position size (20x leverage - maximum)
        bool isLong = true;

        // Need to add more liquidity first to support large position
        vm.startPrank(alice);
        usdc.approve(address(gvault), 1_000_000e6);
        gvault.deposit(1_000_000e6);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(gperp), collateral);

        uint256 positionId = gperp.openPosition(collateral, size, isLong);

        GuildPerp.Position memory position = gperp.getPosition(bob);
        assertEq(position.leverage, MAX_LEVERAGE);

        vm.stopPrank();

        console2.log("Maximum leverage position opened:", position.leverage / 1e18, "x");
    }

    // =============================================================
    //                      POSITION OPENING FAILURE TESTS
    // =============================================================

    function test_open_position_fails_zero_collateral() public {
        vm.startPrank(alice);
        usdc.approve(address(gperp), 100_000e6);

        // Zero collateral should trigger InvalidCollateralAmount, not ZeroAmount
        vm.expectRevert(GuildPerp.GP__InvalidCollateralAmount.selector);
        gperp.openPosition(0, 100_000e6, true);

        vm.stopPrank();
    }

    function test_open_position_fails_zero_size() public {
        vm.startPrank(alice);
        usdc.approve(address(gperp), 50_000e6);

        vm.expectRevert(GuildPerp.GP__ZeroAmount.selector);
        gperp.openPosition(50_000e6, 0, true);

        vm.stopPrank();
    }

    function test_open_position_fails_collateral_too_low() public {
        uint256 collateral = 5_000e6; // Below MIN_COLLATERAL
        uint256 size = 20_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        vm.expectRevert(GuildPerp.GP__InvalidCollateralAmount.selector);
        gperp.openPosition(collateral, size, true);

        vm.stopPrank();
    }

    function test_open_position_fails_collateral_too_high() public {
        uint256 collateral = 1_500_000e6; // Above MAX_COLLATERAL
        uint256 size = 3_000_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        vm.expectRevert(GuildPerp.GP__InvalidCollateralAmount.selector);
        gperp.openPosition(collateral, size, true);

        vm.stopPrank();
    }

    function test_open_position_fails_leverage_too_low() public {
        uint256 collateral = 100_000e6; // $100,000
        uint256 size = 150_000e6; // $150,000 (1.5x leverage - below minimum)

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        vm.expectRevert(GuildPerp.GP__LeverageTooLow.selector);
        gperp.openPosition(collateral, size, true);

        vm.stopPrank();
    }

    function test_open_position_fails_leverage_too_high() public {
        uint256 collateral = 50_000e6; // $50,000
        uint256 size = 1_500_000e6; // $1,500,000 (30x leverage - above maximum)

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        vm.expectRevert(GuildPerp.GP__LeverageTooHigh.selector);
        gperp.openPosition(collateral, size, true);

        vm.stopPrank();
    }

    function test_open_position_fails_duplicate_position() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral * 2);

        // Open first position
        gperp.openPosition(collateral, size, true);

        // Try to open second position - should fail
        vm.expectRevert(GuildPerp.GP__PositionAlreadyExists.selector);
        gperp.openPosition(collateral, size, false);

        vm.stopPrank();
    }

    function test_open_position_fails_when_trading_disabled() public {
        // Disable trading
        vm.prank(admin);
        gperp.toggleTrading();

        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);

        vm.expectRevert(GuildPerp.GP__TradesNotAllowed.selector);
        gperp.openPosition(collateral, size, true);

        vm.stopPrank();
    }

    // =============================================================
    //                      POSITION CLOSING TESTS
    // =============================================================

    function test_close_position_fails_no_position() public {
        vm.startPrank(bob);

        vm.expectRevert(GuildPerp.GP__NoPositionFound.selector);
        gperp.closePosition();

        vm.stopPrank();
    }

    function test_close_position_with_time_based_fees() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);
        gperp.openPosition(collateral, size, true);

        // Update price feed timestamp and simulate 24 hours (1440 minutes)
        vm.warp(block.timestamp + 86400);
        updatePriceFeedForTesting(90000e8);

        uint256 balanceBefore = usdc.balanceOf(alice);

        gperp.closePosition();

        uint256 balanceAfter = usdc.balanceOf(alice);
        uint256 returned = balanceAfter - balanceBefore;

        // Should be less than collateral due to fees
        assertLt(returned, collateral);

        console2.log("Collateral deposited:", collateral);
        console2.log("Amount returned:", returned);
        console2.log("Fees paid:", collateral - returned);

        vm.stopPrank();
    }

    // =============================================================
    //                      PNL CALCULATION TESTS
    // =============================================================

    function test_calculate_pnl_long_position() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);
        gperp.openPosition(collateral, size, true);

        // Calculate PnL immediately (should be close to 0)
        int256 pnl = gperp.calculatePnL(alice);
        console2.log("PnL for long position:", pnl);

        // PnL should be small (close to 0) since we just opened
        assertTrue(pnl >= -1000e6 && pnl <= 1000e6); // Within $1000 range

        vm.stopPrank();
    }

    function test_calculate_pnl_short_position() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(bob);
        usdc.approve(address(gperp), collateral);
        gperp.openPosition(collateral, size, false); // Short position

        // Calculate PnL immediately (should be close to 0)
        int256 pnl = gperp.calculatePnL(bob);
        console2.log("PnL for short position:", pnl);

        // PnL should be small (close to 0) since we just opened
        assertTrue(pnl >= -1000e6 && pnl <= 1000e6); // Within $1000 range

        vm.stopPrank();
    }

    function test_calculate_pnl_no_position() public view {
        int256 pnl = gperp.calculatePnL(clara);
        assertEq(pnl, 0);
    }

    // =============================================================
    //                      LIQUIDATION PRICE TESTS
    // =============================================================

    function test_get_liquidation_price_long() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(alice);
        usdc.approve(address(gperp), collateral);
        gperp.openPosition(collateral, size, true);

        uint256 liqPrice = gperp.getLiquidationPrice(alice);
        assertTrue(liqPrice > 0);

        console2.log("Liquidation price for long position:", liqPrice);

        vm.stopPrank();
    }

    function test_get_liquidation_price_short() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        vm.startPrank(bob);
        usdc.approve(address(gperp), collateral);
        gperp.openPosition(collateral, size, false);

        uint256 liqPrice = gperp.getLiquidationPrice(bob);
        assertTrue(liqPrice > 0);

        console2.log("Liquidation price for short position:", liqPrice);

        vm.stopPrank();
    }

    function test_get_liquidation_price_no_position() public view {
        uint256 liqPrice = gperp.getLiquidationPrice(clara);
        assertEq(liqPrice, 0);
    }

    // =============================================================
    //                      ADMIN FUNCTION TESTS
    // =============================================================

    function test_toggle_trading() public {
        assertTrue(gperp.isTradingAllowed());

        vm.prank(admin);
        gperp.toggleTrading();

        assertFalse(gperp.isTradingAllowed());

        vm.prank(admin);
        gperp.toggleTrading();

        assertTrue(gperp.isTradingAllowed());
    }

    function test_set_trading_fee() public {
        uint256 newFee = 5; // 0.005% per minute

        vm.prank(admin);
        gperp.setTradingFeePerMinute(newFee);

        assertEq(gperp.getTradingFeePerMinute(), newFee);
    }

    function test_set_trading_fee_fails_too_high() public {
        uint256 tooHighFee = 200; // 0.2% per minute (above max of 0.1%)

        vm.prank(admin);
        vm.expectRevert("Fee too high");
        gperp.setTradingFeePerMinute(tooHighFee);
    }

    function test_admin_functions_fail_non_admin() public {
        vm.startPrank(alice);

        vm.expectRevert(GuildPerp.GP__NotAllowed.selector);
        gperp.toggleTrading();

        vm.expectRevert(GuildPerp.GP__NotAllowed.selector);
        gperp.setTradingFeePerMinute(5);

        vm.stopPrank();
    }

    // =============================================================
    //                      LIQUIDITY MANAGEMENT TESTS
    // =============================================================

    function test_supply_liquidity_only_vault() public {
        uint256 amount = 100_000e6;
        uint256 initialLiquidity = gperp.getTotalLiquidity();

        // Should work from vault
        vm.prank(address(gvault));
        gperp.supplyLiquidity(amount);

        assertEq(gperp.getTotalLiquidity(), initialLiquidity + amount);

        // Should fail from non-vault
        vm.prank(alice);
        vm.expectRevert(GuildPerp.GP__NotAllowed.selector);
        gperp.supplyLiquidity(amount);
    }

    function test_exit_liquidity_only_vault() public {
        uint256 supplyAmount = 100_000e6;
        uint256 initialLiquidity = gperp.getTotalLiquidity();

        // Supply liquidity first
        vm.prank(address(gvault));
        gperp.supplyLiquidity(supplyAmount);

        uint256 liquidityAfterSupply = gperp.getTotalLiquidity();
        assertEq(liquidityAfterSupply, initialLiquidity + supplyAmount);

        // For exitLiquidity, we need to use a small share amount that corresponds
        // to a portion of the supplied liquidity. Let's try converting some assets to shares first
        uint256 assetsToExit = 50_000e6; // $50,000 worth
        uint256 sharesToExit = gvault.convertToShares(assetsToExit);

        // Exit some liquidity using the calculated shares
        vm.prank(address(gvault));
        gperp.exitLiquidity(sharesToExit);

        // Should have reduced liquidity (but we can't predict exact amount due to fees/conversion)
        uint256 liquidityAfterExit = gperp.getTotalLiquidity();
        assertLt(liquidityAfterExit, liquidityAfterSupply);

        console2.log("Initial liquidity:", initialLiquidity);
        console2.log("After supply:", liquidityAfterSupply);
        console2.log("After exit:", liquidityAfterExit);
        console2.log("Shares used for exit:", sharesToExit);
    }

    function test_exit_liquidity_fails_insufficient() public {
        uint256 supplyAmount = 100_000e6;
        uint256 exitShares = type(uint256).max; // Massive amount of shares

        vm.prank(address(gvault));
        gperp.supplyLiquidity(supplyAmount);

        vm.prank(address(gvault));
        vm.expectRevert(GuildPerp.GP__InsufficientLiquidity.selector);
        gperp.exitLiquidity(exitShares);
    }

    // =============================================================
    //                      UTILITY FUNCTION TESTS
    // =============================================================

    function test_has_position() public {
        assertFalse(gperp.hasPosition(alice));

        vm.startPrank(alice);
        usdc.approve(address(gperp), 50_000e6);
        gperp.openPosition(50_000e6, 200_000e6, true);
        vm.stopPrank();

        assertTrue(gperp.hasPosition(alice));
    }

    function test_get_position_duration() public {
        vm.startPrank(alice);
        usdc.approve(address(gperp), 50_000e6);
        gperp.openPosition(50_000e6, 200_000e6, true);
        vm.stopPrank();

        // Initially should be 0 or very small
        uint256 duration1 = gperp.getPositionDuration(alice);
        assertTrue(duration1 < 10); // Less than 10 seconds

        // Advance time by 1 hour
        vm.warp(block.timestamp + 3600);

        uint256 duration2 = gperp.getPositionDuration(alice);
        assertEq(duration2, 3600); // Should be exactly 1 hour

        console2.log("Position duration after 1 hour:", duration2, "seconds");
    }

    // =============================================================
    //                      EDGE CASE TESTS
    // =============================================================

    function test_multiple_users_different_positions() public {
        // Alice opens long position
        vm.startPrank(alice);
        usdc.approve(address(gperp), 50_000e6);
        uint256 alicePositionId = gperp.openPosition(50_000e6, 200_000e6, true);
        vm.stopPrank();

        // Bob opens short position
        vm.startPrank(bob);
        usdc.approve(address(gperp), 25_000e6);
        uint256 bobPositionId = gperp.openPosition(25_000e6, 100_000e6, false);
        vm.stopPrank();

        // Verify both positions exist and are different
        assertTrue(gperp.hasPosition(alice));
        assertTrue(gperp.hasPosition(bob));
        assertNotEq(alicePositionId, bobPositionId);

        GuildPerp.Position memory alicePos = gperp.getPosition(alice);
        GuildPerp.Position memory bobPos = gperp.getPosition(bob);

        assertTrue(alicePos.status); // Long
        assertFalse(bobPos.status); // Short

        console2.log("Alice position ID:", alicePositionId);
        console2.log("Bob position ID:", bobPositionId);
    }

    function test_zero_address_validations() public {
        vm.expectRevert(GuildPerp.GP__ZeroAddress.selector);
        gperp.calculatePnL(address(0));
    }

    // =============================================================
    //                      INTEGRATION TESTS
    // =============================================================

    function test_full_trading_cycle() public {
        uint256 collateral = 50_000e6;
        uint256 size = 200_000e6;

        // Step 1: Open position
        vm.startPrank(alice);
        uint256 initialBalance = usdc.balanceOf(alice);
        usdc.approve(address(gperp), collateral);

        uint256 positionId = gperp.openPosition(collateral, size, true);

        // Verify balance decreased by collateral
        assertEq(usdc.balanceOf(alice), initialBalance - collateral);
        assertTrue(gperp.hasPosition(alice));

        // Step 2: Wait some time and update price feed
        vm.warp(block.timestamp + 1800); // 30 minutes
        updatePriceFeedForTesting(90000e8);

        // Step 3: Check PnL
        int256 pnl = gperp.calculatePnL(alice);
        console2.log("PnL after 30 minutes:", pnl);

        // Step 4: Close position
        gperp.closePosition();

        // Step 5: Verify position is closed
        assertFalse(gperp.hasPosition(alice));

        uint256 finalBalance = usdc.balanceOf(alice);
        console2.log("Initial balance:", initialBalance);
        console2.log("Final balance:", finalBalance);
        console2.log("Net change:", int256(finalBalance) - int256(initialBalance));

        vm.stopPrank();
    }
}
