# Guild Perpetual DEX (GPD)

A minimal perpetuals prototype consisting of three contracts:

- `GuildToken` (GTK): ERC20 share token minted/burned against vault deposits/withdrawals
- `GuildVault`: Asset custodian that mints/burns GTK shares and pipes liquidity to the perp engine
- `GuildPerp`: Perp engine that tracks positions, PnL, and time-based trading fees using a BTC/USD oracle

Built with Foundry, OpenZeppelin, and Chainlink.


## Table of contents

- What you get
- Architecture overview
- Contracts and APIs
  - GuildToken
  - GuildVault
  - GuildPerp
- Price feeds and configuration
- Deploy and wire
- Using the system (flows)
- Testing
- Design notes and assumptions
- Next steps
- License


## What you get

- A working ERC20 share token (`GuildToken`) controlled by the vault
- A vault (`GuildVault`) that:
  - accepts deposits in a quote asset (USDC mock)
  - mints GTK shares proportional to TVL
  - withdraws assets by burning GTK shares
  - routes liquidity to/from `GuildPerp`
- A perp engine (`GuildPerp`) that:
  - opens/closes BTC positions (long/short)
  - calculates PnL from a Chainlink BTC/USD feed
  - charges a time-based trading fee per open minute


## Architecture overview

High-level components and responsibilities:

- `GuildToken` (GTK):
  - Ownable (admin) token
  - `setVault` once to authorize the vault as the sole minter/burner

- `GuildVault`:
  - Holds the quote asset (USDC)
  - Mints GTK on deposit, burns GTK on withdrawal
  - Calls `supplyLiquidity` / `exitLiquidity` on the perp to track available liquidity
  - Computes shares <-> assets via mulDiv with TVL and total supply

- `GuildPerp`:
  - Tracks a single-asset market (BTC) quoted in the vault asset (USDC)
  - Validates collateral and a basic leverage constraint
  - Stores per-trader `Position` (collateral, size, entryPrice, leverage, isLong)
  - On close, realizes PnL using the current oracle price and charges a time-based fee


## Contracts and APIs

### GuildToken

File: `src/GuildToken.sol`

- Ownable ERC20 share token (name: GuildToken, symbol: GTK)
- Roles
  - Admin (constructor param) can call `setVault`
  - Vault (address set by admin) can call `mint` and `burn`
- Key functions
  - `setVault(address vault)` onlyAdmin
  - `mint(address to, uint256 value)` onlyVault
  - `burn(address from, uint256 value)` onlyVault
- Getters
  - `getAdmin()`
  - `getVault()`
  - `getTotalSupply()`

Errors: `GTK__ZeroAddress`, `GTK__NotAdmin`, `GTK__NotVault`, `GTK__VaultNotSet`
Events: `VaultSet(address)`


### GuildVault

File: `src/GuildVault.sol`

- Custodian of the quote asset (USDC) and GTK supply
- Holds pointers to the asset, the GTK token, and the perp engine
- Admin can set the perp once and pre-approve it to spend vault assets

Key functions
- Admin wiring
  - `setPerp(address perp)` onlyAdmin
    - Sets the perp address and increases allowance for the perp to pull funds as needed
- User-facing
  - `deposit(uint256 assetAmount)`
    - Transfers USDC from the user, calls `gPerp.supplyLiquidity`, mints GTK proportional to TVL
  - `withdraw(uint256 sharesAmount)`
    - Burns GTK and transfers USDC to the user after calling `gPerp.exitLiquidity` if needed
- Conversions
  - `convertToShares(uint256 assetAmount)` view
  - `convertToAssets(uint256 sharesAmount)` view

Internal math
- Uses OpenZeppelin `Math.mulDiv` with rounding to avoid precision loss
- `s_totalAssets` tracks TVL inside the vault (after perp accounting)

Getters
- `getPerp()`
- `getAdmin()`
- `getTotalAssets()`

Errors: `GV__NotAdmin`, `GV__ZeroAddress`, `GV__ZeroAmount`, `GV__InvalidShares`, `GV__InsufficientLiquidity`
Events: `GV__PerpSet`, `GV__Deposited`, `GV__Withdrew`


### GuildPerp

File: `src/GuildPerp.sol`

- Perp engine for a single BTC/USD market
- Uses Chainlink AggregatorV3Interface with a stale-check helper (`OracleChecker`)

Key storage
- `iUSD` (collateral/quote asset)
- `iBTC` (traded asset)
- `gToken`, `gVault`
- Leverage/collateral constants
  - `MIN_LEVERAGE = 2`, `MAX_LEVERAGE = 20`
  - `MIN_COLLATERAL = 10_000e6`, `MAX_COLLATERAL = 1_000_000e6`
- Fee
  - `tradingFeePerMinute = 1` (0.001% per minute, i.e. 0.06% per hour)
- Price feed mapping `s_priceFeed[token] = aggregator`

Position struct
- `collateralAmount`
- `size` (notional size in quote units)
- `entryPrice` (from oracle, scaled to 1e18)
- `leverage = size / collateral`
- `status` (true = long, false = short)

Key external functions
- `openPosition(uint256 collateral, uint256 size, bool isLong) returns (uint256 positionId)`
  - Transfers `collateral` USDC from trader
  - Validates collateral bounds and a basic leverage window relative to min/max collateral
  - Stores position, timestamps open time, emits `GP__PositionOpened`
- `closePosition()`
  - Computes PnL using current price vs entry, applies to `collateralAmount`
  - Charges `tradingFeePerMinute * minutesOpen / 100000` of the position value
  - Sends fee to vault and returns remainder to trader
  - Clears position and emits `GP__PositionClosed` and `GP__TradingFeeCollected`

View
- `getBTCPrice()` -> Chainlink price scaled to 1e18
- `calculatePnL(address trader)` -> signed PnL in quote units
- `getPositionById(uint256 id)`
- `getOwnerOfPosition(uint256 id)`
- `getTradingFeePerMinute()`
- `getPositionDuration(address trader)`

Vault-only
- `supplyLiquidity(uint256 amount)`
- `exitLiquidity(uint256 amount)`

Admin-only
- `setTradingFeePerMinute(uint256 newFee)` (max 0.1% per minute)

Errors: `GP__ZeroAddress`, `GP__ZeroAmount`, `GP__NotAllowed`, `GP__SizeError`, `GP__TradesNotAllowed`, `GP__TradesCurrentlyActive`, `GP__InsufficientLiquidity`
Events: `GP__PositionOpened`, `GP__PositionClosed`, `GP__BTCPriceUpdated`, `GP__TradingFeeCollected`

Notes
- A boolean `allowed` flag and modifiers exist (`tradesAllowed`, `tradesPaused`), but on/off setters aren’t yet exposed; add admin toggles if you want a kill-switch.


## Price feeds and configuration

File: `script/HelperConfig.s.sol`

- Provides per-chain addresses for:
  - Chainlink BTC/USD price feed
  - WBTC mock (local) or address (Sepolia)
  - USDC mock (local) or address (Sepolia)
- Supported chain IDs:
  - Local Anvil: 31337 → deploys mocks (`MockV3Aggregator`, `ERC20Mock` for WBTC/USDC)
  - Sepolia: 11155111 → uses known feed and token addresses

Expose via:
- `HelperConfig.getConfigByChainId(block.chainid)`
- `DeployGuildDex.deployPerp()` consumes this config


## Deploy and wire

Prereqs
- Foundry (forge/cast)
- A private key with funds for the target network (for non-local)

Deploy
- Script: `script/DeployGuildDex.s.sol`
- Produces three contracts: `GuildToken`, `GuildVault`, `GuildPerp`

Post-deploy wiring (required)
1) Set the vault as the authorized minter/burner of GTK
   - `GuildToken.setVault(gvault)` (admin only)
2) Set the perp on the vault and approve spending
   - `GuildVault.setPerp(gperp)` (admin only)

The unit test shows these lines explicitly:
- `gtoken.setVault(address(gvault));`
- `gvault.setPerp(address(gperp));`


## Using the system (flows)

All token amounts below assume USDC has 6 decimals and WBTC has 8 decimals (mocks follow OZ ERC20Mock behavior).

Deposit (become LP)
- Approve and call `GuildVault.deposit(assetAmount)`
- Vault mints GTK shares proportional to TVL
- Vault calls `GuildPerp.supplyLiquidity(assetAmount)` to update available liquidity

Withdraw (redeem LP)
- Call `GuildVault.withdraw(sharesAmount)`
- Vault burns GTK and returns proportional USDC
- Vault can call `GuildPerp.exitLiquidity` if it needs to reduce the perp’s tracked liquidity

Open a position
- Call `GuildPerp.openPosition(collateral, size, isLong)`
  - Collateral bounds: `10,000e6 <= collateral <= 1,000,000e6`
  - Basic leverage check via `size / collateral`
  - Entry price pulled from Chainlink with stale-check

Close a position
- Call `GuildPerp.closePosition()`
  - Computes signed PnL (long: price up → gain; short: price down → gain)
  - Applies time-based fee and returns net USDC to the trader, fee to the vault

PnL units
- PnL is denominated in the quote asset’s smallest unit (e.g., USDC 6 decimals) after scaling math


## Testing

- Unit tests live in `test/unit/TestGuildDex.t.sol`
- Mocks are under `test/mocks`
- Example checks include deposit/share math and price feed access

Quickstart (local)

```
forge test -vvv
```

Dry-run deploy (local Anvil)

```
forge script script/DeployGuildDex.s.sol --fork-url http://localhost:8545 --broadcast -vvv
```

Sepolia deploy (example)

```
forge script script/DeployGuildDex.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```


## Design notes and assumptions

- Single-market prototype (BTC/USD). Extending to multiple markets would require mapping of market state and per-asset feeds.
- Leverage checks are basic and primarily ensure collateral falls within min/max bounds; refine to explicit target leverage bounds if desired.
- The `allowed` trading switch is present but no admin setter is exposed; add toggling functions for pausability.
- Fee model is time-based and linear per minute. Consider capping or applying it on notional instead of position value.
- Price feed scaling assumes 8-decimal oracle answers (standard Chainlink USD feeds). `getBTCPrice` scales to 1e18 for internal math.


## Next steps

- Add liquidations (admin hook exists in initial spec but not implemented)
- Add explicit `pauseTrading/unpauseTrading` admin functions
- Expand test coverage (PnL edge cases, fee accrual over long periods, vault accounting with partial withdrawals)
- Introduce multi-market support and isolated margin per market
- Emit additional events (funding, liquidation, pause/unpause)


## License

SPDX: UNLICENSED (as per source files). Consider adopting a permissive OSS license if sharing publicly.
