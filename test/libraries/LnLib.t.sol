// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

// Libraries
import { LnLib } from "../../src/libraries/LnLib.sol";

contract LnLibTest is BaseTest, Helpers {
    // Default params: p(s) = 1·ln(s + 1) + 0
    // c=1 ensures ln(s+c) > 0 for all s >= 0, and ln(0+1) = 0 at origin
    bytes internal defaultParams;

    // Scaled params: p(s) = 2·ln(s + 1) + 5
    // Tests that both scale factor `a` and offset `b` apply correctly
    bytes internal scaledOffsetParams;

    // Large shift: p(s) = 1·ln(s + 100) + 0
    // c=100 means ln(s+c) is never near zero — tests the shift parameter in isolation
    bytes internal largeShiftParams;

    // Fractional scale: p(s) = 0.5·ln(s + 1) + 10
    // Sub-unit `a` to verify fractional fixed-point multiplication with ln
    bytes internal fractionalParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = ln(s + 1)
        defaultParams = abi.encode(Types.LnParams({ a: 1e18, b: 0, c: 1e18 }));

        // p(s) = 2·ln(s + 1) + 5
        scaledOffsetParams = abi.encode(Types.LnParams({ a: 2e18, b: 5e18, c: 1e18 }));

        // p(s) = ln(s + 100)
        largeShiftParams = abi.encode(Types.LnParams({ a: 1e18, b: 0, c: 100e18 }));

        // p(s) = 0.5·ln(s + 1) + 10
        fractionalParams = abi.encode(Types.LnParams({ a: 0.5e18, b: 10e18, c: 1e18 }));

        // Reusable segment: LN over [0, 1000e18] with default params
        defaultSegments.push(_createLnSegment(0, 1000e18));
    }

    /*//////////////////////////////////////////////////////////////
                    SPOT PRICE: p(s) = a·ln(s + c) + b
    //////////////////////////////////////////////////////////////*/

    // ── Default: p(s) = ln(s + 1) ────────────────────────────────

    function test_spotPrice_default_atZero() public view {
        // p(0) = ln(0 + 1) = ln(1) = 0
        SD59x18 price = LnLib.spotPrice(defaultParams, sd(0));
        assertEq(price.unwrap(), 0);
    }

    function test_spotPrice_default_atEMinusOne() public view {
        // p(e - 1) = ln(e - 1 + 1) = ln(e) = 1
        // e ≈ 2.718281828459045e18, so s = e - 1 ≈ 1.718281828459045e18
        SD59x18 price = LnLib.spotPrice(defaultParams, sd(1_718281828459045235));
        assertApproxEqRel(uint256(price.unwrap()), 1e18, 0.0001e18); // 0.01%
    }

    function test_spotPrice_default_atLargeSupply() public view {
        // p(99) = ln(100) ≈ 4.60517
        SD59x18 price = LnLib.spotPrice(defaultParams, sd(99e18));
        assertApproxEqRel(uint256(price.unwrap()), 4_605170185988091368, 0.0001e18);
    }

    function test_spotPrice_default_monotonicallyIncreasing() public view {
        SD59x18 p1 = LnLib.spotPrice(defaultParams, sd(1e18));
        SD59x18 p2 = LnLib.spotPrice(defaultParams, sd(10e18));
        SD59x18 p3 = LnLib.spotPrice(defaultParams, sd(100e18));

        assertTrue(p2 > p1);
        assertTrue(p3 > p2);
    }

    // ── Scaled + offset: p(s) = 2·ln(s + 1) + 5 ────────────────

    function test_spotPrice_scaledOffset_atZero() public view {
        // p(0) = 2·ln(1) + 5 = 0 + 5 = 5
        SD59x18 price = LnLib.spotPrice(scaledOffsetParams, sd(0));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_scaledOffset_atEMinusOne() public view {
        // p(e-1) = 2·ln(e) + 5 = 2·1 + 5 = 7
        SD59x18 price = LnLib.spotPrice(scaledOffsetParams, sd(1_718281828459045235));
        assertApproxEqRel(uint256(price.unwrap()), 7e18, 0.0001e18);
    }

    function test_spotPrice_scaledOffset_atNinetyNine() public view {
        // p(99) = 2·ln(100) + 5 ≈ 2·4.60517 + 5 ≈ 14.21034
        SD59x18 price = LnLib.spotPrice(scaledOffsetParams, sd(99e18));
        assertApproxEqRel(uint256(price.unwrap()), 14_210340371976182736, 0.0001e18);
    }

    // ── Large shift: p(s) = ln(s + 100) ─────────────────────────

    function test_spotPrice_largeShift_atZero() public view {
        // p(0) = ln(0 + 100) = ln(100) ≈ 4.60517
        SD59x18 price = LnLib.spotPrice(largeShiftParams, sd(0));
        assertApproxEqRel(uint256(price.unwrap()), 4_605170185988091368, 0.0001e18);
    }

    function test_spotPrice_largeShift_atHundred() public view {
        // p(100) = ln(200) = ln(2) + ln(100) ≈ 0.69315 + 4.60517 ≈ 5.29832
        SD59x18 price = LnLib.spotPrice(largeShiftParams, sd(100e18));
        assertApproxEqRel(uint256(price.unwrap()), 5_298317366548036870, 0.0001e18);
    }

    function test_spotPrice_largeShift_growsSlowerThanDefault() public view {
        // ln(s + 100) grows slower than ln(s + 1) for large s because
        // the +100 shift makes the argument's relative change smaller
        SD59x18 defaultDiff = LnLib.spotPrice(defaultParams, sd(100e18))
            - LnLib.spotPrice(defaultParams, sd(10e18));
        SD59x18 shiftDiff = LnLib.spotPrice(largeShiftParams, sd(100e18))
            - LnLib.spotPrice(largeShiftParams, sd(10e18));

        assertTrue(defaultDiff > shiftDiff);
    }

    // ── Fractional: p(s) = 0.5·ln(s + 1) + 10 ──────────────────

    function test_spotPrice_fractional_atZero() public view {
        // p(0) = 0.5·ln(1) + 10 = 0 + 10 = 10
        SD59x18 price = LnLib.spotPrice(fractionalParams, sd(0));
        assertEq(price.unwrap(), 10e18);
    }

    function test_spotPrice_fractional_atEMinusOne() public view {
        // p(e-1) = 0.5·ln(e) + 10 = 0.5 + 10 = 10.5
        SD59x18 price = LnLib.spotPrice(fractionalParams, sd(1_718281828459045235));
        assertApproxEqRel(uint256(price.unwrap()), 10.5e18, 0.0001e18);
    }

    function test_spotPrice_fractional_isHalfOfDefault_plusOffset() public view {
        // p_frac(s) = 0.5·ln(s+1) + 10
        // p_default(s) = ln(s+1)
        // So p_frac(s) - 10 = 0.5 · p_default(s)
        SD59x18 s = sd(50e18);
        SD59x18 pFrac = LnLib.spotPrice(fractionalParams, s);
        SD59x18 pDefault = LnLib.spotPrice(defaultParams, s);

        SD59x18 fracMinusOffset = pFrac - sd(10e18);
        SD59x18 halfDefault = pDefault / sd(2e18);

        assertApproxEqRel(uint256(fracMinusOffset.unwrap()), uint256(halfDefault.unwrap()), 0.0001e18);
    }
}