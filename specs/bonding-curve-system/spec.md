# Bonding Curve System Spec

## Metadata
- Project: Bonding
- Milestone: Core Protocol MVP
- Interview Date: 2026-02-23
- Predicted LoC: ~4,200 (see Scope Estimate section)
- **Scope Warning: Predicted >2,000 LoC - phased implementation recommended**

## Summary

A permissionless bonding curve protocol where anyone can deploy configurable bonding curves via a `CurveFactory`. Each curve uses a **mint/burn model** — tokens are minted on buy and burned on sell, with prices determined by piecewise mathematical formulas (up to 3 segments). The system supports 6 formula types: linear, logarithmic (ln), sinusoidal, parabolic, exponential, and sigmoid. Collateral is any ERC20 token, and a fixed protocol fee is charged on every trade.

Curves can optionally include linear token vesting and have configurable graduation behavior — when a curve reaches its max threshold, a `GraduationManager` migrates liquidity to a Uniswap V4 pool. All core contracts (Curve, Vesting) are deployed as EIP-1167 minimal clone proxies via the factory. The system is designed for multi-chain deployment with comprehensive anti-manipulation protections.

---

## Requirements

### Functional

1. **Curve Creation**: Users call `CurveFactory.createCurve()` to deploy a new bonding curve. The factory creates the token (plain ERC20), initializes the Curve clone, and registers it in an EnumerableSet.
2. **Piecewise Pricing**: Each curve defines 1-3 piecewise formula segments. The creator specifies the formula type, mathematical parameters, and the token supply range for each segment.
3. **Buy Tokens**: Users send collateral ERC20 tokens to buy curve tokens. Tokens are minted to the buyer. Price is calculated via `PriceLib` based on current supply position on the piecewise curve.
4. **Sell Tokens**: Users burn curve tokens to receive collateral back. Price follows the same curve in reverse.
5. **Protocol Fee**: A fixed percentage fee is deducted from every buy/sell transaction and sent to a protocol treasury address.
6. **Graduation**: When a curve's collateral or supply reaches the configured max threshold, the curve triggers graduation via `GraduationManager`, which creates a Uniswap V4 pool and migrates liquidity.
7. **Vesting (Optional)**: Curve creators can enable linear vesting with a cliff. Purchased tokens are locked in a `Vesting` contract and release linearly over the configured duration.
8. **Anti-Manipulation**: Slippage protection on all trades and max buy/sell limits per transaction.

### Non-Functional

- **Multi-chain**: Deployable on Ethereum L1 and L2s (Base and Optimism) without modification.
- **Gas Efficiency**: Clone proxies for curve and vesting deployments. Library-based pricing (no external calls for price calculation).
- **Precision**: PRBMath SD59x18/UD60x18 fixed-point arithmetic for all pricing formulas.
- **Security**: ReentrancyGuard on all state-changing external functions. SafeERC20 for all token transfers. Checks-effects-interactions pattern throughout.
- **Permissionless**: No admin roles, no upgradeability, no pause mechanisms. Protocol fee is immutable at deployment.

---

## Technical Design

### Architecture Overview

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
     |  (Library)     |                      | PoolManager      |
     +--------+-------+                      +-----------------+
              |
              | delegates to
              |
   +----------+----------+----------+----------+----------+
   |          |          |          |          |          |
+--v---+ +---v--+ +---v--+ +---v----+ +---v--+ +---v----+
|Linear| | Ln   | | Sin  | |Parabolic| | Exp | |Sigmoid |
| Lib  | | Lib  | | Lib  | |  Lib   | | Lib | |  Lib   |
+------+ +------+ +------+ +--------+ +------+ +--------+
```

### Contract Specifications

#### CurveFactory.sol
- **Role**: Entry point. Deploys and registers Curve clones.
- **State**:
  - `address public curveImplementation` — Curve logic contract address
  - `address public vestingImplementation` — Vesting logic contract address
  - `address public graduationManager` — GraduationManager address
  - `address public protocolTreasury` — Fee recipient
  - `uint256 public protocolFeeBps` — Fee in basis points (immutable)
  - `EnumerableSet.AddressSet private _curves` — Registry of all deployed curves
- **Key Functions**:
  - `createCurve(string name, string symbol, uint8 decimals, address collateralToken, PiecewiseConfig[] segments, CurveConfig config, VestingConfig vestingConfig)` → deploys token + Curve clone + optional Vesting clone
  - `getCurves()` → returns all registered curve addresses
  - `getCurveCount()` → returns number of deployed curves
- **Clone Deployment**: Uses OpenZeppelin `Clones.clone()` for Curve and Vesting instances

#### Curve.sol
- **Role**: Core bonding curve. Handles buy/sell, fee collection, graduation trigger.
- **Inherits**: `Initializable`, `ReentrancyGuard`
- **State**:
  - `IERC20 public collateralToken` — The ERC20 used as collateral
  - `IERC20 public curveToken` — The ERC20 minted/burned by this curve
  - `PiecewiseSegment[] public segments` — Pricing formula configuration
  - `CurveConfig public config` — Thresholds, timeout, graduation settings
  - `address public vestingContract` — Optional vesting contract address
  - `address public factory` — Parent factory address
  - `bool public graduated` — Whether the curve has graduated
  - `uint256 public maxBuyPerTx` — Max tokens purchasable per transaction
  - `uint256 public maxSellPerTx` — Max tokens sellable per transaction
- **Key Functions**:
  - `initialize(...)` — Called by factory after clone deployment
  - `buy(uint256 collateralAmount, uint256 minTokensOut)` — Buy tokens with slippage protection
  - `sell(uint256 tokenAmount, uint256 minCollateralOut)` — Sell tokens with slippage protection
  - `graduate()` — Trigger graduation when threshold is met (callable by anyone)
  - `getPrice(uint256 supply)` — View: returns current token price at a given supply
  - `getBuyQuote(uint256 collateralAmount)` — View: returns tokens receivable for a collateral amount
  - `getSellQuote(uint256 tokenAmount)` — View: returns collateral receivable for a token amount
- **Buy Flow**:
  1. Check not graduated, check max per tx
  2. Calculate tokens to mint via `PriceLib.calculateBuyTokens(segments, currentSupply, collateralAmount)`
  3. Check `minTokensOut` slippage
  4. Deduct protocol fee from collateral, transfer fee to treasury
  5. Transfer remaining collateral from buyer to this contract
  6. Mint tokens to buyer (or to vesting contract if vesting is enabled)
  7. Check if graduation threshold is met, trigger if so
- **Sell Flow**:
  1. Check not graduated, check max per tx
  2. Calculate collateral to return via `PriceLib.calculateSellCollateral(segments, currentSupply, tokenAmount)`
  3. Check `minCollateralOut` slippage
  4. Burn tokens from seller
  5. Deduct protocol fee from collateral, transfer fee to treasury
  6. Transfer remaining collateral to seller

#### PriceLib.sol (Library)
- **Role**: Pure library for price calculations. No state, no proxy needed.
- **Key Functions**:
  - `calculateBuyTokens(PiecewiseSegment[], uint256 currentSupply, uint256 collateralIn)` → `uint256 tokensOut`
  - `calculateSellCollateral(PiecewiseSegment[], uint256 currentSupply, uint256 tokensIn)` → `uint256 collateralOut`
  - `getSpotPrice(PiecewiseSegment[], uint256 supply)` → `uint256 price`
  - `integrate(PiecewiseSegment, uint256 fromSupply, uint256 toSupply)` → `uint256 area`
- **Pricing Math**: Uses definite integrals of the price function over supply ranges to calculate exact collateral/token amounts (area under the curve).
- **Delegates to sub-libraries**: `LinearLib`, `LnLib`, `SinLib`, `ParabolicLib`, `ExponentialLib`, `SigmoidLib`

#### Formula Libraries (src/libraries/)
Each library exposes two core functions using PRBMath SD59x18:

| Library | Formula p(s) | Parameters | Integral |
|---------|-------------|------------|----------|
| **LinearLib** | `p = m * s + b` | m (slope), b (intercept) | `m*s^2/2 + b*s` |
| **LnLib** | `p = a * ln(s + c) + b` | a (scale), b (offset), c (shift) | `a*[(s+c)*ln(s+c) - (s+c)] + b*s` |
| **SinLib** | `p = a * sin(w*s + phi) + b` | a (amplitude), w (frequency), phi (phase), b (offset) | `-a/w * cos(w*s + phi) + b*s` |
| **ParabolicLib** | `p = a * s^2 + b * s + c` | a, b, c (coefficients) | `a*s^3/3 + b*s^2/2 + c*s` |
| **ExponentialLib** | `p = a * e^(k*s) + b` | a (scale), k (growth rate), b (offset) | `a/k * e^(k*s) + b*s` |
| **SigmoidLib** | `p = L / (1 + e^(-k*(s - s0))) + b` | L (max), k (steepness), s0 (midpoint), b (offset) | `L/k * ln(1 + e^(k*(s-s0))) + b*s` |

> **Note**: `s` = token supply, `p(s)` = price at supply `s`. All math uses SD59x18 fixed-point (18 decimal places).

#### Piecewise Segment Configuration
```solidity
enum FormulaType { LINEAR, LN, SIN, PARABOLIC, EXPONENTIAL, SIGMOID }

struct FormulaParams {
    int256[] params;  // SD59x18 encoded parameters, meaning varies by FormulaType
}

struct PiecewiseSegment {
    FormulaType formulaType;
    FormulaParams params;
    uint256 supplyStart;  // Token supply where this segment begins
    uint256 supplyEnd;    // Token supply where this segment ends
}
```

#### GraduationManager.sol
- **Role**: Singleton contract that handles liquidity migration to Uniswap V4.
- **Key Functions**:
  - `graduate(address curve, address token, address collateral, uint256 tokenAmount, uint256 collateralAmount)` — Called by Curve.sol when graduation threshold is met
- **Uniswap V4 Integration**:
  1. Call `PoolManager.initialize()` to create the pool with appropriate fee tier and tick spacing
  2. Add full-range liquidity via `PoolManager.modifyLiquidity()`
  3. Transfer LP position ownership (or lock it permanently)
- **Note**: Specific V4 hook integration can be added later. MVP focuses on basic pool creation + liquidity addition.

#### Vesting.sol
- **Role**: Optional linear vesting for tokens purchased through a bonding curve.
- **Inherits**: `Initializable`
- **State**:
  - `IERC20 public token` — The vested token
  - `uint256 public cliffDuration` — Time before any tokens unlock
  - `uint256 public vestingDuration` — Total vesting duration after cliff
  - `mapping(address => VestingSchedule) public schedules`
- **Key Functions**:
  - `initialize(address token, uint256 cliff, uint256 duration)` — Called by factory
  - `addVesting(address beneficiary, uint256 amount)` — Called by Curve.sol when tokens are bought
  - `claim()` — Beneficiary claims unlocked tokens
  - `claimable(address beneficiary)` → `uint256` — View: returns currently claimable amount
- **Vesting Math**: `unlocked = total * (block.timestamp - startTime - cliff) / vestingDuration`

#### Token Contract (ERC20, created by factory)
- Plain `ERC20Upgradeable` with `Initializable`
- **Minting/Burning**: Only the associated `Curve.sol` contract can mint and burn
- **No extensions**: No permit, no votes, no other features for MVP
- **Initialized via**: `initialize(string name, string symbol, uint8 decimals, address minter)`

### Interfaces

| Interface | Key Definitions |
|-----------|----------------|
| `ICurve.sol` | `buy()`, `sell()`, `graduate()`, `getPrice()`, events, errors, structs |
| `ICurveFactory.sol` | `createCurve()`, `getCurves()`, events, errors |
| `IGraduationManager.sol` | `graduate()`, events |
| `IVesting.sol` | `addVesting()`, `claim()`, `claimable()`, events |

### Data Flow: Buy Tokens

```
User                  CurveFactory       Curve          PriceLib        Token        Treasury
  |                        |               |               |              |             |
  |--- createCurve() ----->|               |               |              |             |
  |                        |-- clone() --->|               |              |             |
  |                        |-- initialize->|               |              |             |
  |                        |               |               |              |             |
  |--- buy(amount, min) ---|-------------->|               |              |             |
  |                        |               |-- calculate ->|              |             |
  |                        |               |<-- tokens ----|              |             |
  |                        |               |-- transferFrom(collateral) ->|             |
  |                        |               |-- transfer fee --------------|------------>|
  |                        |               |-- mint tokens -------------->|             |
  |                        |               |               |              |             |
```

---

## Scope Estimate

**Predicted LoC: ~4,200**

| Component | Estimated LoC | Details |
|-----------|--------------|---------|
| CurveFactory.sol | ~200 | Clone deployment, registry, createCurve overloads |
| Curve.sol | ~350 | Buy/sell, initialization, graduation trigger, limits |
| GraduationManager.sol | ~180 | Uniswap V4 pool creation + liquidity migration |
| Vesting.sol | ~150 | Linear vesting with cliff, claim logic |
| Token (ERC20) | ~60 | Plain ERC20 with minter-only mint/burn |
| PriceLib.sol | ~120 | Piecewise routing, integration dispatcher |
| Formula Libraries (6) | ~550 | ~80-100 LoC each for spot price + integral |
| Interfaces (4) | ~200 | Structs, events, errors, function signatures |
| **Subtotal (contracts)** | **~1,810** | |
| Unit Tests | ~1,200 | Per-function tests for all contracts |
| Fuzz Tests | ~500 | PRBMath formula fuzzing, buy/sell invariants |
| Integration Tests | ~500 | Full flow: create -> buy -> sell -> graduate |
| Invariant Tests | ~200 | Collateral backing, supply consistency |
| **Subtotal (tests)** | **~2,400** | |
| **Total** | **~4,200** | |

### Risk Assessment: Exceeds 2,000 LoC limit - phased split recommended

**Recommended Split:**

| Phase | Scope | Est. LoC |
|-------|-------|----------|
| **Phase 1: Core Bonding Curve** | CurveFactory, Curve, Token, PriceLib, LinearLib + ParabolicLib, interfaces, core tests | ~1,800 |
| **Phase 2: Advanced Formulas** | LnLib, SinLib, ExponentialLib, SigmoidLib + formula fuzz tests | ~900 |
| **Phase 3: Graduation** | GraduationManager, Uniswap V4 integration, graduation tests | ~700 |
| **Phase 4: Vesting + Hardening** | Vesting.sol, whitelist logic, invariant tests, integration tests | ~800 |

---

## Implementation Plan

### Phase 1: Core Bonding Curve (~1,800 LoC)
- [ ] Define all interfaces: `ICurve`, `ICurveFactory`, `IGraduationManager`, `IVesting`
- [ ] Define shared structs: `PiecewiseSegment`, `FormulaType`, `FormulaParams`, `CurveConfig`
- [ ] Implement plain ERC20 token contract with minter-restricted mint/burn
- [ ] Implement `LinearLib` (spot price + integral)
- [ ] Implement `ParabolicLib` (spot price + integral)
- [ ] Implement `PriceLib` (piecewise routing, `calculateBuyTokens`, `calculateSellCollateral`)
- [ ] Implement `Curve.sol` (initialize, buy, sell, slippage protection, max per-tx limits, fee collection)
- [ ] Implement `CurveFactory.sol` (createCurve, clone deployment, EnumerableSet registry)
- [ ] Install PRBMath dependency (`forge install PaulRBerg/prb-math`)
- [ ] Write unit tests for LinearLib and ParabolicLib
- [ ] Write unit tests for PriceLib (piecewise routing)
- [ ] Write unit tests for Curve.sol (buy, sell, edge cases)
- [ ] Write unit tests for CurveFactory.sol (creation, registry)
- [ ] Write basic fuzz tests for linear/parabolic formula accuracy

### Phase 2: Advanced Formulas (~900 LoC)
- [ ] Implement `LnLib` using PRBMath `ln()` and `exp()`
- [ ] Implement `SinLib` using solidity-trigonometry + PRBMath
- [ ] Implement `ExponentialLib` using PRBMath `exp()`
- [ ] Implement `SigmoidLib` using PRBMath `exp()` + `ln()`
- [ ] Register new formula types in `PriceLib` routing
- [ ] Write unit tests for each new formula library
- [ ] Write fuzz tests ensuring formula continuity at segment boundaries
- [ ] Write fuzz tests for numerical precision bounds

### Phase 3: Graduation (~700 LoC)
- [ ] Install Uniswap V4 dependencies (`forge install Uniswap/v4-core Uniswap/v4-periphery`)
- [ ] Implement `IGraduationManager` interface
- [ ] Implement `GraduationManager.sol` (pool initialization, liquidity addition)
- [ ] Add graduation trigger logic in `Curve.sol` (`graduate()` function)
- [ ] Write unit tests for GraduationManager
- [ ] Write integration test: full create -> buy to threshold -> graduate flow
- [ ] Test edge cases: graduation with dust amounts, re-graduation prevention

### Phase 4: Vesting + Hardening (~800 LoC)
- [ ] Implement `IVesting` interface
- [ ] Implement `Vesting.sol` (initialize, addVesting, claim, claimable)
- [ ] Update `Curve.sol` buy flow to route tokens to Vesting when enabled
- [ ] Update `CurveFactory.sol` to deploy Vesting clones when configured
- [ ] Implement whitelist phase logic in `Curve.sol`
- [ ] Write unit tests for Vesting.sol (cliff, linear unlock, claim)
- [ ] Write integration tests for buy-with-vesting flow
- [ ] Write invariant tests:
  - Collateral reserve always >= sum of sell values for all outstanding tokens
  - Total supply matches expected position on curve
  - Vesting schedules sum to total vested tokens
- [ ] Gas benchmarking on all critical paths

---

## Test Plan

### Unit Tests
- [ ] `LinearLib`: spot price correctness, integral accuracy, zero/edge inputs
- [ ] `ParabolicLib`: spot price correctness, integral accuracy, negative coefficients
- [ ] `LnLib`: spot price correctness, integral accuracy, domain validation (s + c > 0)
- [ ] `SinLib`: spot price correctness, integral accuracy, phase/frequency edge cases
- [ ] `ExponentialLib`: spot price correctness, integral accuracy, overflow protection
- [ ] `SigmoidLib`: spot price correctness, integral accuracy, extreme steepness values
- [ ] `PriceLib`: piecewise routing, segment boundary transitions, multi-segment integration
- [ ] `Curve.sol`: buy, sell, getPrice, getBuyQuote, getSellQuote, initialization, access control
- [ ] `CurveFactory.sol`: createCurve (both overloads), getCurves, getCurveCount
- [ ] `Vesting.sol`: addVesting, claim, claimable, cliff behavior, full unlock
- [ ] `GraduationManager.sol`: graduate, pool creation verification

### Fuzz Tests
- [ ] Formula libraries: random valid inputs produce non-negative prices
- [ ] Buy/sell roundtrip: buy then sell returns <= original collateral (no profit extraction)
- [ ] Piecewise continuity: price at segment boundaries matches between adjacent segments
- [ ] PRBMath precision: verify formula outputs within acceptable error bounds (< 0.01%)

### Integration Tests
- [ ] Full lifecycle: create curve -> buy tokens -> sell tokens -> verify balances
- [ ] Graduation flow: create -> buy to threshold -> graduate -> verify Uniswap V4 pool
- [ ] Vesting flow: create with vesting -> buy -> wait cliff -> partial claim -> full claim
- [ ] Multi-curve: create multiple curves from same factory, verify isolation
- [ ] Fee accounting: verify protocol treasury receives correct fees across multiple trades

### Invariant Tests
- [ ] `collateral_balance >= integral(0, currentSupply)` — collateral always backs outstanding tokens
- [ ] `token.totalSupply() == expected_supply_on_curve` — supply consistency
- [ ] `sum(vesting_schedules) == total_vested` — vesting accounting integrity

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| PRBMath precision loss in complex formulas (ln, sigmoid) | Medium | High | Fuzz test all formulas against Python reference implementations. Set acceptable error bounds. |
| Uniswap V4 API changes (still maturing) | Medium | Medium | Abstract behind `IGraduationManager` interface. Phase 3 can adapt to API changes without touching Curve.sol. |
| Reentrancy on buy/sell via malicious ERC20 collateral | Low | Critical | ReentrancyGuard on all external functions. SafeERC20. CEI pattern. |
| Piecewise segment discontinuities causing arbitrage | Medium | High | Validate segment boundaries at creation time (price must be continuous). Fuzz test boundary transitions. |
| Gas costs too high for complex formulas on L1 | Medium | Low | Library-based approach (no external calls). PRBMath is gas-optimized. Multi-chain design means L2 is primary target. |
| Clone proxy initialization front-running | Low | Medium | Factory creates and initializes in same transaction. No gap between deploy and init. |
| Overflow in exponential/sigmoid for large supply values | Medium | High | Cap formula inputs. Use PRBMath's built-in overflow checks. Validate params at curve creation. |

---

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Buy/sell model? | Mint/burn (MVP). Token created with curve. | User |
| Graduation mechanism? | Separate GraduationManager.sol, configurable (DEX or LP migration) | User |
| Target DEX for graduation? | Uniswap V4 (PoolManager singleton) | User |
| Pricing parameters? | Full custom params set by curve creator | User |
| Protocol fees? | Fixed % fee, immutable, sent to protocol treasury | User |
| Access control? | Fully permissionless. No admin roles. | User |
| Vesting model? | Linear vesting with cliff, optional per curve | User |
| Collateral tokens? | Any ERC20 | User |
| Fixed-point math? | PRBMath SD59x18/UD60x18 | User |
| Anti-manipulation? | Full: slippage + max per-tx + optional whitelist phase | User |
| Token standard? | Plain ERC20 (no permit, no votes) | User |
| Target chain? | Multi-chain (L1 + L2) | User |
| Formula set? | Linear, Ln, Sin, Parabolic, Exponential, Sigmoid (6 total) | User |
| PriceCalculator architecture? | Pure library (PriceLib), not a clone proxy | User |
| Testing level? | Comprehensive: unit + fuzz + integration + invariant | User |

---

## Interview Notes

**Q: Buy/sell mechanism?**
A: Default is mint/burn with token created alongside the curve. Future support for existing tokens (fixed supply / hybrid) deferred post-MVP.

**Q: Graduation behavior?**
A: Configurable — either DEX migration or liquidity pool migration. Implemented as a separate GraduationManager.sol contract.

**Q: Pricing formula configuration?**
A: Full custom parameters. Curve creator sets all mathematical parameters for each piecewise segment.

**Q: Protocol fees?**
A: Fixed percentage fee on every buy/sell, sent to protocol treasury. Immutable (fully permissionless design).

**Q: Graduation target DEX?**
A: Uniswap V4 singleton architecture. GraduationManager calls PoolManager.initialize() and modifyLiquidity().

**Q: Vesting model?**
A: Linear vesting with cliff period. Optional per curve.

**Q: Collateral support?**
A: Any ERC20 token. Need proper decimal handling in pricing.

**Q: Additional formulas?**
A: Add exponential (e^x) and sigmoid (S-curve) to the existing set. 6 formulas total.

**Q: PriceCalculator architecture?**
A: Pure library approach. PriceLib is a Solidity library used directly by Curve.sol. No clone proxy needed.

**Q: Access control?**
A: Fully permissionless. No admin, no pause, no upgradeability. Fee is immutable.

**Q: Fixed-point math?**
A: PRBMath (SD59x18/UD60x18) by Paul Razvan Berg. Industry standard.

**Q: Anti-manipulation?**
A: Full protection — slippage protection (min out params), max buy/sell per transaction, optional whitelist phase for early buyers.

**Q: Chain target?**
A: Multi-chain. Designed to deploy on Ethereum L1 and L2s without modification.

**Q: Token standard?**
A: Plain ERC20. No permit, no votes. Keep it minimal for MVP.

**Q: Testing strategy?**
A: Comprehensive — unit tests for every function, fuzz tests for math libraries, integration tests for full flows, invariant tests for protocol guarantees.
