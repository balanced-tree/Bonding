# Bonding

A permissionless bonding curve protocol where anyone can deploy configurable bonding curves via a `CurveFactory`. Each curve uses a **mint/burn model** — tokens are minted on buy and burned on sell, with prices determined by piecewise mathematical formulas supporting up to 3 segments.

## How It Works

1. **Create a Curve** — Call `CurveFactory.createCurve()` to deploy a new bonding curve. The factory creates an ERC20 token, initializes a Curve clone proxy, and registers it.
2. **Buy Tokens** — Send collateral (any ERC20) to buy curve tokens. Tokens are minted to the buyer at a price determined by the current supply position on the curve.
3. **Sell Tokens** — Burn curve tokens to receive collateral back. Price follows the same curve in reverse.
4. **Graduate** — When a curve reaches its max threshold, a `GraduationManager` migrates liquidity to a Uniswap V4 pool.

## Architecture

```
                     +------------------+
                     |  CurveFactory    |
                     |  (Entry Point)   |
                     +--------+---------+
                              |
                createCurve() | deploys clones
                              |
          +-------------------+-------------------+
          |                   |                   |
 +--------v-------+  +-------v--------+  +-------v--------+
 |   Curve.sol    |  |  Vesting.sol   |  | GraduationMgr  |
 | (Clone Proxy)  |  | (Clone Proxy)  |  |  (Singleton)   |
 +--------+-------+  +----------------+  +-------+--------+
          |                                       |
          | uses                                  | calls
          |                                       |
 +--------v-------+                      +--------v--------+
 |   PriceLib     |                      | Uniswap V4      |
 |  (Library)     |                      | PoolManager     |
 +----------------+                      +-----------------+
```

### Contracts

| Contract | Role |
|----------|------|
| `CurveFactory.sol` | Entry point. Deploys Curve + Token + Vesting clones via EIP-1167 minimal proxies. Maintains an EnumerableSet registry of all deployed curves. |
| `Curve.sol` | Core bonding curve. Handles buy/sell with slippage protection, fee collection, max per-tx limits, and graduation trigger. |
| `PriceLib.sol` | Pure library for piecewise price calculations. Routes to formula-specific sub-libraries (`LinearLib`, `LnLib`, `SinLib`, `ParabolicLib`, `ExponentialLib`, `SigmoidLib`). |
| `Vesting.sol` | Optional linear token vesting with cliff. Purchased tokens lock in a Vesting clone and release linearly over a configured duration. |
| `GraduationManager.sol` | Singleton that creates a Uniswap V4 pool and migrates liquidity when a curve graduates. |
| `Token (ERC20)` | ERC20Upgradeable deployed as an EIP-1167 clone proxy. Uses `Initializable` for clone-compatibility (not for upgradeability — clones point to a fixed implementation). Minter-restricted mint/burn. Created by the factory alongside each curve. |

### Interfaces

| Interface | Key Functions |
|-----------|--------------|
| `ICurve.sol` | `buy()`, `sell()`, `graduate()`, `getPrice()`, `getBuyQuote()`, `getSellQuote()` |
| `ICurveFactory.sol` | `createCurve()`, `getCurves()`, `getCurveCount()` |
| `IGraduationManager.sol` | `graduate()` |
| `IVesting.sol` | `addVesting()`, `claim()`, `claimable()` |

## Key Features

- **Protocol Fee** — Fixed percentage fee (in basis points) on every buy/sell, sent to a protocol treasury. Immutable at deployment.
- **Vesting (Optional)** — Linear vesting with cliff period. When enabled, purchased tokens route to a Vesting contract instead of the buyer directly.
- **Anti-Manipulation** — Slippage protection (`minTokensOut` / `minCollateralOut`) and max buy/sell limits per transaction.
- **Permissionless** — No admin roles, no pause mechanisms, no logic upgradeability. EIP-1167 clones point to fixed implementations.
- **Multi-chain** — Deployable on Ethereum L1 and L2s (Base, Optimism) without modification.
- **Gas Efficient** — EIP-1167 clone proxies for Curve and Vesting deployments. Library-based pricing with no external calls.

## Buy / Sell Flow

**Buy:**
1. Check curve has not graduated; check max per-tx limit
2. Calculate tokens to mint via `PriceLib.calculateBuyTokens(segments, currentSupply, collateralAmount)`
3. Enforce slippage (`minTokensOut`)
4. Deduct protocol fee from collateral, transfer fee to treasury
5. Transfer remaining collateral from buyer to Curve contract
6. Mint tokens to buyer (or to Vesting contract if vesting is enabled)
7. Check graduation threshold, trigger if met

**Sell:**
1. Check curve has not graduated; check max per-tx limit
2. Calculate collateral to return via `PriceLib.calculateSellCollateral(segments, currentSupply, tokenAmount)`
3. Enforce slippage (`minCollateralOut`)
4. Burn tokens from seller
5. Deduct protocol fee from collateral, transfer fee to treasury
6. Transfer remaining collateral to seller

## Supported Formula Types

Each curve defines 1–3 piecewise segments. Six formula types are available:

| Formula | Price Function `p(s)` | Parameters |
|---------|----------------------|------------|
| **Linear** | `m * s + b` | slope, intercept |
| **Logarithmic** | `a * ln(s + c) + b` | scale, offset, shift |
| **Sinusoidal** | `a * sin(w*s + phi) + b` | amplitude, frequency, phase, offset |
| **Parabolic** | `a * s² + b * s + c` | coefficients |
| **Exponential** | `a * e^(k*s) + b` | scale, growth rate, offset |
| **Sigmoid** | `L / (1 + e^(-k*(s - s₀))) + b` | max, steepness, midpoint, offset |

All math uses [PRBMath](https://github.com/PaulRBerg/prb-math) SD59x18 fixed-point arithmetic (18 decimal places). Prices are computed via definite integrals of the price function over supply ranges (area under the curve).

## Design Notes

### Why ERC20Upgradeable for a Non-Upgradeable Token?

All per-curve contracts (Curve, Vesting, and Token) are deployed as [EIP-1167 minimal clone proxies](https://eips.ethereum.org/EIPS/eip-1167). Clones are ~45-byte contracts that `delegatecall` to a shared, **fixed** implementation. Because constructors don't run on clones, the token needs an `initialize()` function to set its name, symbol, and minter — which is what `ERC20Upgradeable` provides.

**This does NOT make the token upgradeable.** Unlike UUPS or Transparent Proxy patterns, EIP-1167 clones cannot be re-pointed to a different implementation. The implementation address is hardcoded in the clone's bytecode at deploy time. The `Upgradeable` in the name refers only to initializer-compatibility, not actual upgradeability.

For full design rationale, see [specs/bonding-curve-system/spec.md](specs/bonding-curve-system/spec.md#token-contract-design-choice).

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)

### Setup

```shell
# Clone the repository
git clone <repo-url>
cd Bonding

# Install dependencies (forge submodules)
forge install

# Build
forge build
```

### Test

```shell
# Run all tests
forge test

# Run a specific test
forge test --match-test <test_name>

# Run tests with gas reporting
forge test --gas-report
```

### Format

```shell
forge fmt
```

### Local Node

```shell
anvil
```

## Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) — ERC20, ReentrancyGuard, SafeERC20, Clones
- [OpenZeppelin Contracts Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) — ERC20Upgradeable, Initializable
- [PRBMath](https://github.com/PaulRBerg/prb-math) — SD59x18/UD60x18 fixed-point arithmetic
- [solidity-trigonometry](https://github.com/mds1/solidity-trigonometry) — On-chain sin/cos for sinusoidal formula
- [Forge Std](https://github.com/foundry-rs/forge-std) — Foundry test utilities

## License

MIT
