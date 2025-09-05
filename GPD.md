# GuildDex

A decentralized perpetual trading protocol built on Ethereum, allowing users to trade leveraged positions on cryptocurrency pairs with liquidity provided through a vault system.

## Overview

GuildDex consists of three main components:
- **GuildVault**: Manages liquidity deposits and withdrawals with share-based accounting
- **GuildPerp**: Handles perpetual trading positions with leverage up to 20x
- **GuildToken**: ERC20 token representing vault shares

## Features

- **Leveraged Trading**: Open long/short positions with 2x to 20x leverage
- **Liquidity Provision**: Earn fees by providing liquidity to the vault
- **Time-based Fees**: Dynamic fee structure based on position duration
- **Oracle Integration**: Chainlink price feeds for accurate pricing
- **Risk Management**: Built-in liquidation mechanisms and collateral requirements

## Architecture

### GuildVault
- Accepts USDC deposits and issues GuildTokens as shares
- Supplies liquidity to the perpetual trading contract
- Implements ERC4626-like vault mechanics
- Handles withdrawals and share redemption

### GuildPerp
- Manages perpetual trading positions
- Supports both long and short positions
- Implements leverage validation (2x-20x)
- Calculates PnL based on price movements
- Handles position liquidation and fee collection

### GuildToken
- ERC20 token representing vault ownership
- Minted when users deposit to vault
- Burned when users withdraw from vault
- Controlled by vault contract

## Getting Started

### Prerequisites

- Foundry
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd guilddex
```

2. Install dependencies:
```bash
npm install
forge install
```

3. Copy environment file:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
RPC_URL=your_rpc_url
```

### Building

```bash
forge build
```

### Testing

Run all tests:
```bash
forge test
```

Run tests with verbosity:
```bash
forge test -vvv
```

Run specific test file:
```bash
forge test --match-path test/unit/TestGuildDex.t.sol
```

### Deployment

Deploy to local network:
```bash
forge script script/DeployGuildDex.s.sol --rpc-url http://localhost:8545 --broadcast
```

Deploy to testnet:
```bash
forge script script/DeployGuildDex.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Usage

### For Liquidity Providers

1. **Deposit Liquidity**:
   ```solidity
   // Approve USDC to vault
   usdc.approve(address(vault), amount);
   
   // Deposit and receive GuildTokens
   vault.deposit(amount);
   ```

2. **Withdraw Liquidity**:
   ```solidity
   // Withdraw using GuildToken shares
   vault.withdraw(shares);
   ```

### For Traders

1. **Open Position**:
   ```solidity
   // Approve USDC collateral
   usdc.approve(address(perp), collateralAmount);
   
   // Open long position
   uint256 positionId = perp.openPosition(
       collateralAmount,  // Collateral in USDC
       positionSize,      // Position size in USDC
       true              // true for long, false for short
   );
   ```

2. **Close Position**:
   ```solidity
   // Close your active position
   perp.closePosition();
   ```

3. **Check Position Status**:
   ```solidity
   // Get position details
   GuildPerp.Position memory position = perp.getPosition(userAddress);
   
   // Calculate current PnL
   int256 pnl = perp.calculatePnL(userAddress);
   
   // Get liquidation price
   uint256 liqPrice = perp.getLiquidationPrice(userAddress);
   ```

## Configuration

### Trading Parameters

- **Minimum Collateral**: $10,000 USDC
- **Maximum Collateral**: $1,000,000 USDC
- **Leverage Range**: 2x to 20x
- **Base Trading Fee**: 0.01% per minute
- **Maximum Fee**: 0.1% per minute

### Supported Assets

- **Collateral**: USDC
- **Trading Pair**: BTC/USD (via Chainlink oracle)

## Smart Contract Addresses

### Mainnet
*Contracts not yet deployed to mainnet*

### Testnet (Sepolia)
*Update with actual deployment addresses*

```
GuildToken: 0x...
GuildVault: 0x...
GuildPerp: 0x...
```

## Risk Disclaimers

⚠️ **Important Risk Warnings**:

- **Liquidation Risk**: Positions can be liquidated if losses approach collateral value
- **Market Risk**: Cryptocurrency prices are highly volatile
- **Smart Contract Risk**: Code has not been audited by third parties
- **Impermanent Loss**: Liquidity providers may experience losses during high volatility

## Security

### Implemented Protections

- **Reentrancy Guards**: All external functions protected
- **Access Controls**: Admin functions restricted to authorized addresses
- **Input Validation**: Comprehensive parameter validation
- **Oracle Checks**: Price feed staleness verification
- **Overflow Protection**: SafeMath operations throughout

### Known Limitations

- Single asset pair support (BTC/USD only)
- No cross-margin functionality
- Limited oracle redundancy
- No insurance fund mechanism

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write comprehensive tests for new features
- Follow Solidity style guide
- Add natspec documentation for public functions
- Ensure gas optimization where possible

## Testing

The test suite covers:

- ✅ Position opening/closing
- ✅ Leverage validation
- ✅ PnL calculations
- ✅ Liquidity management
- ✅ Fee calculations
- ✅ Access controls
- ✅ Error handling
- ✅ Integration scenarios

### Test Categories

- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Multi-contract interactions
- **Edge Cases**: Boundary conditions and error states
- **Gas Tests**: Gas consumption optimization

## Roadmap

### Phase 1 (Current)
- [x] Core trading functionality
- [x] Basic vault system
- [x] Single pair trading (BTC/USD)
- [x] Comprehensive testing

### Phase 2 (Planned)
- [ ] Multi-asset support
- [ ] Advanced order types
- [ ] Insurance fund
- [ ] Governance token

### Phase 3 (Future)
- [ ] Cross-chain deployment
- [ ] Advanced risk management
- [ ] Automated market making
- [ ] Mobile interface

## License

This project is licensed under the UNLICENSED License - see the [LICENSE](LICENSE) file for details.

## Contact

- **Documentation**: [Link to docs]
- **Discord**: [Discord invite]
- **Twitter**: [@GuildDex]
- **Email**: team@guilddex.com

## Acknowledgments

- OpenZeppelin for secure contract templates
- Chainlink for reliable price feeds
- Foundry for development framework
- The DeFi community for inspiration and feedback

---

**Disclaimer**: This software is experimental and unaudited. Use at your own risk. Never invest more than you can afford to lose.

### Resources

- https://youtu.be/DRZogmD647U?t=11268
- https://updraft.cyfrin.io/courses/gmx-perpetuals-trading
