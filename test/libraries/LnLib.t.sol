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

    /*//////////////////////////////////////////////////////////////
            INTEGRATE: ∫(a·ln(s + c) + b) ds
                     = a·[(s+c)·ln(s+c) - (s+c)] + b·s
    //////////////////////////////////////////////////////////////*/

    // ── Default: ∫ ln(s + 1) ds ─────────────────────────────────

    function test_integrate_default_zeroToZero() public view {
        // Zero-width integral = 0
        SD59x18 area = LnLib.integrate(defaultParams, sd(0), sd(0));
        assertEq(area.unwrap(), 0);
    }

    function test_integrate_default_zeroToOne() public view {
        // ∫₀¹ ln(s+1) ds = [F(1) - F(0)]
        // F(s) = (s+1)·ln(s+1) - (s+1)
        // F(1) = 2·ln(2) - 2 ≈ 2·0.693147 - 2 = -0.613706
        // F(0) = 1·ln(1) - 1 = -1
        // area = -0.613706 - (-1) = 0.386294
        SD59x18 area = LnLib.integrate(defaultParams, sd(0), sd(1e18));
        assertApproxEqRel(uint256(area.unwrap()), 0.386294361119890618e18, 0.0001e18);
    }

    function test_integrate_default_zeroToEMinusOne() public view {
        // ∫₀^(e-1) ln(s+1) ds
        // F(e-1) = e·ln(e) - e = e - e = 0
        // F(0) = 1·ln(1) - 1 = -1
        // area = 0 - (-1) = 1
        SD59x18 eMinus1 = sd(1_718281828459045235);
        SD59x18 area = LnLib.integrate(defaultParams, sd(0), eMinus1);
        assertApproxEqRel(uint256(area.unwrap()), 1e18, 0.001e18);
    }

    function test_integrate_default_nonZeroStart() public view {
        // ∫₁₀²⁰ ln(s+1) ds = F(20) - F(10)
        // F(20) = 21·ln(21) - 21 ≈ 21·3.044522 - 21 = 63.934968 - 21 = 42.934968
        // F(10) = 11·ln(11) - 11 ≈ 11·2.397895 - 11 = 26.376852 - 11 = 15.376852
        // area ≈ 42.934968 - 15.376852 = 27.558116
        SD59x18 area = LnLib.integrate(defaultParams, sd(10e18), sd(20e18));
        assertApproxEqRel(uint256(area.unwrap()), 27_558116109637648000, 0.001e18);
    }

    // ── Scaled + offset: ∫ (2·ln(s+1) + 5) ds ──────────────────

    function test_integrate_scaledOffset_zeroToTen() public view {
        // ∫₀¹⁰ (2·ln(s+1) + 5) ds = 2·[F_ln(10) - F_ln(0)] + 5·10
        // F_ln(s) = (s+1)·ln(s+1) - (s+1)
        // F_ln(10) = 11·ln(11) - 11 ≈ 15.376852
        // F_ln(0)  = -1
        // ln part = 2·(15.376852 - (-1)) = 2·16.376852 = 32.753704
        // b part = 50
        // total ≈ 82.753704
        SD59x18 area = LnLib.integrate(scaledOffsetParams, sd(0), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 82_753704438375846000, 0.001e18);
    }

    // ── Flat: ∫ (0.5·ln(s+1) + 10) ds ──────────────────────────

    function test_integrate_fractional_zeroToTen() public view {
        // ∫₀¹⁰ (0.5·ln(s+1) + 10) ds = 0.5·[F_ln(10) - F_ln(0)] + 10·10
        // = 0.5·16.376852 + 100 = 8.188426 + 100 ≈ 108.188426
        SD59x18 area = LnLib.integrate(fractionalParams, sd(0), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 108_188426109593961000, 0.001e18);
    }

    function test_integrate_fractional_offsetDominates() public view {
        // For large ranges, the b·s term (10·s) should dwarf the ln term
        SD59x18 area = LnLib.integrate(fractionalParams, sd(0), sd(100e18));
        // b·s component alone = 10·100 = 1000
        // Total should be close to but larger than 1000
        assertTrue(area.unwrap() > 1000e18);
        // The ln part for 0.5·ln(s+1) over [0,100] is modest
        assertTrue(area.unwrap() < 1200e18);
    }

    // ── Large shift: ∫ ln(s + 100) ds ───────────────────────────

    function test_integrate_largeShift_zeroToHundred() public view {
        // ∫₀¹⁰⁰ ln(s+100) ds = F(100) - F(0)
        // F(s) = (s+100)·ln(s+100) - (s+100)
        // F(100) = 200·ln(200) - 200 ≈ 200·5.298317 - 200 = 1059.663 - 200 = 859.663
        // F(0)   = 100·ln(100) - 100 ≈ 100·4.605170 - 100 = 460.517 - 100 = 360.517
        // area ≈ 859.663 - 360.517 ≈ 499.146
        SD59x18 area = LnLib.integrate(largeShiftParams, sd(0), sd(100e18));
        assertApproxEqRel(uint256(area.unwrap()), 499_146318053945544000, 0.001e18);
    }

    /*//////////////////////////////////////////////////////////////
                          ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀³⁰ = ∫₀¹⁰ + ∫₁₀³⁰
        SD59x18 whole = LnLib.integrate(defaultParams, sd(0), sd(30e18));
        SD59x18 part1 = LnLib.integrate(defaultParams, sd(0), sd(10e18));
        SD59x18 part2 = LnLib.integrate(defaultParams, sd(10e18), sd(30e18));

        assertApproxEqAbs(whole.unwrap(), (part1 + part2).unwrap(), 1);
    }

    function test_integrate_additivity_scaledOffset() public view {
        SD59x18 whole = LnLib.integrate(scaledOffsetParams, sd(0), sd(50e18));
        SD59x18 part1 = LnLib.integrate(scaledOffsetParams, sd(0), sd(20e18));
        SD59x18 part2 = LnLib.integrate(scaledOffsetParams, sd(20e18), sd(50e18));

        assertApproxEqAbs(whole.unwrap(), (part1 + part2).unwrap(), 1);
    }

    function test_integrate_additivity_threeWaySplit() public view {
        SD59x18 whole = LnLib.integrate(defaultParams, sd(0), sd(60e18));
        SD59x18 p1 = LnLib.integrate(defaultParams, sd(0), sd(15e18));
        SD59x18 p2 = LnLib.integrate(defaultParams, sd(15e18), sd(40e18));
        SD59x18 p3 = LnLib.integrate(defaultParams, sd(40e18), sd(60e18));

        assertApproxEqAbs(whole.unwrap(), (p1 + p2 + p3).unwrap(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For tiny δ: ∫(s, s+δ) ≈ p(s)·δ
        SD59x18 s = sd(50e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = LnLib.spotPrice(defaultParams, s);
        SD59x18 area = LnLib.integrate(defaultParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function test_spotIntegralConsistency_scaledOffset() public view {
        SD59x18 s = sd(25e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = LnLib.spotPrice(scaledOffsetParams, s);
        SD59x18 area = LnLib.integrate(scaledOffsetParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    
}