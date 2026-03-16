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
import { SinLib } from "../../src/libraries/SinLib.sol";

contract SinLibTest is BaseTest, Helpers {
    // Default params: p(s) = 1·sin(1·s + 0) + 2
    // b=2 keeps price non-negative since amplitude a=1 means sin oscillates in [-1, 1]
    bytes internal defaultParams;

    // High offset: p(s) = 1·sin(1·s + 0) + 10
    // Large b dwarfs the oscillation — tests that the b·s term dominates the integral
    bytes internal highOffsetParams;

    // Scaled amplitude: p(s) = 3·sin(1·s + 0) + 5
    // Amplitude 3 means oscillation in [-3, 3], offset 5 keeps price in [2, 8]
    bytes internal scaledAmplitudeParams;

    // Phase-shifted: p(s) = 1·sin(1·s + π/2) + 2
    // phi = π/2 turns sin into cos — tests the phase shift and negative angle normalization
    bytes internal phaseShiftedParams;

    // High frequency: p(s) = 1·sin(10·s + 0) + 2
    // w=10 compresses oscillations — stresses the trig lookup table precision
    bytes internal highFreqParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = sin(s) + 2
        defaultParams = abi.encode(Types.SinParams({ a: 1e18, w: 1e18, phi: 0, b: 2e18 }));

        // p(s) = sin(s) + 10
        highOffsetParams = abi.encode(Types.SinParams({ a: 1e18, w: 1e18, phi: 0, b: 10e18 }));

        // p(s) = 3·sin(s) + 5
        scaledAmplitudeParams = abi.encode(Types.SinParams({ a: 3e18, w: 1e18, phi: 0, b: 5e18 }));

        // p(s) = sin(s + π/2) + 2   (≈ cos(s) + 2)
        // π/2 ≈ 1.5707963...e18
        phaseShiftedParams = abi.encode(Types.SinParams({ a: 1e18, w: 1e18, phi: 1_570796326794896619, b: 2e18 }));

        // p(s) = sin(10·s) + 2
        highFreqParams = abi.encode(Types.SinParams({ a: 1e18, w: 10e18, phi: 0, b: 2e18 }));

        // Reusable segment: SIN over [0, 1000e18] with default params
        defaultSegments.push(_createSinSegment(0, 1000e18));
    }

    /// @dev π ≈ 3.14159265358979323846e18
    int256 internal constant PI = 3_141592653589793238;
    /// @dev π/2
    int256 internal constant HALF_PI = 1_570796326794896619;

    /// @dev Wider tolerance for trig lookup table (0.1%)
    uint256 internal constant TRIG_TOLERANCE = 0.001e18;

    /*//////////////////////////////////////////////////////////////
              SPOT PRICE: p(s) = a·sin(w·s + phi) + b
    //////////////////////////////////////////////////////////////*/

    // ── Default: p(s) = sin(s) + 2 ──────────────────────────────

    function test_spotPrice_default_atZero() public view {
        // p(0) = sin(0) + 2 = 0 + 2 = 2
        SD59x18 price = SinLib.spotPrice(defaultParams, sd(0));
        assertEq(price.unwrap(), 2e18);
    }

    function test_spotPrice_default_atHalfPi() public view {
        // p(π/2) = sin(π/2) + 2 = 1 + 2 = 3
        SD59x18 price = SinLib.spotPrice(defaultParams, sd(HALF_PI));
        assertApproxEqRel(uint256(price.unwrap()), 3e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_default_atPi() public view {
        // p(π) = sin(π) + 2 = 0 + 2 = 2
        SD59x18 price = SinLib.spotPrice(defaultParams, sd(PI));
        assertApproxEqRel(uint256(price.unwrap()), 2e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_default_atThreeHalfPi() public view {
        // p(3π/2) = sin(3π/2) + 2 = -1 + 2 = 1
        SD59x18 price = SinLib.spotPrice(defaultParams, sd(3 * HALF_PI));
        assertApproxEqRel(uint256(price.unwrap()), 1e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_default_atTwoPi() public view {
        // p(2π) = sin(2π) + 2 = 0 + 2 = 2 (full cycle)
        SD59x18 price = SinLib.spotPrice(defaultParams, sd(2 * PI));
        assertApproxEqRel(uint256(price.unwrap()), 2e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_default_alwaysPositive() public view {
        // min(sin(s)) = -1, so min price = -1 + 2 = 1 > 0
        // Check at the minimum (s = 3π/2) and several other points
        SD59x18 pMin = SinLib.spotPrice(defaultParams, sd(3 * HALF_PI));
        SD59x18 pZero = SinLib.spotPrice(defaultParams, sd(0));
        SD59x18 pMax = SinLib.spotPrice(defaultParams, sd(HALF_PI));

        assertTrue(pMin.unwrap() > 0);
        assertTrue(pZero.unwrap() > 0);
        assertTrue(pMax.unwrap() > 0);
    }

    function test_spotPrice_default_periodic() public view {
        // sin is 2π-periodic: p(s) == p(s + 2π)
        SD59x18 s = sd(1e18);
        SD59x18 price1 = SinLib.spotPrice(defaultParams, s);
        SD59x18 price2 = SinLib.spotPrice(defaultParams, s + sd(2 * PI));

        assertApproxEqRel(uint256(price1.unwrap()), uint256(price2.unwrap()), TRIG_TOLERANCE);
    }

    // ── High offset: p(s) = sin(s) + 10 ─────────────────────────

    function test_spotPrice_highOffset_atZero() public view {
        // p(0) = sin(0) + 10 = 10
        SD59x18 price = SinLib.spotPrice(highOffsetParams, sd(0));
        assertEq(price.unwrap(), 10e18);
    }

    function test_spotPrice_highOffset_sameOscillationAsDefault() public view {
        // Both have a=1, w=1, phi=0 — only b differs
        // So p_high(s) - p_default(s) = 10 - 2 = 8 for all s
        SD59x18 s = sd(2e18);
        SD59x18 pHigh = SinLib.spotPrice(highOffsetParams, s);
        SD59x18 pDefault = SinLib.spotPrice(defaultParams, s);

        assertEq((pHigh - pDefault).unwrap(), 8e18);
    }

    // ── Scaled amplitude: p(s) = 3·sin(s) + 5 ──────────────────

    function test_spotPrice_scaledAmplitude_atZero() public view {
        // p(0) = 3·sin(0) + 5 = 5
        SD59x18 price = SinLib.spotPrice(scaledAmplitudeParams, sd(0));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_scaledAmplitude_atHalfPi() public view {
        // p(π/2) = 3·sin(π/2) + 5 = 3 + 5 = 8
        SD59x18 price = SinLib.spotPrice(scaledAmplitudeParams, sd(HALF_PI));
        assertApproxEqRel(uint256(price.unwrap()), 8e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_scaledAmplitude_atThreeHalfPi() public view {
        // p(3π/2) = 3·sin(3π/2) + 5 = 3·(-1) + 5 = 2
        SD59x18 price = SinLib.spotPrice(scaledAmplitudeParams, sd(3 * HALF_PI));
        assertApproxEqRel(uint256(price.unwrap()), 2e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_scaledAmplitude_rangeIs6() public view {
        // max = 3·1 + 5 = 8, min = 3·(-1) + 5 = 2, range = 6
        SD59x18 pMax = SinLib.spotPrice(scaledAmplitudeParams, sd(HALF_PI));
        SD59x18 pMin = SinLib.spotPrice(scaledAmplitudeParams, sd(3 * HALF_PI));

        assertApproxEqRel(uint256((pMax - pMin).unwrap()), 6e18, TRIG_TOLERANCE);
    }

    // ── Phase-shifted: p(s) = sin(s + π/2) + 2  ≈  cos(s) + 2 ─

    function test_spotPrice_phaseShifted_atZero() public view {
        // p(0) = sin(0 + π/2) + 2 = sin(π/2) + 2 = 1 + 2 = 3
        SD59x18 price = SinLib.spotPrice(phaseShiftedParams, sd(0));
        assertApproxEqRel(uint256(price.unwrap()), 3e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_phaseShifted_atHalfPi() public view {
        // p(π/2) = sin(π/2 + π/2) + 2 = sin(π) + 2 = 0 + 2 = 2
        SD59x18 price = SinLib.spotPrice(phaseShiftedParams, sd(HALF_PI));
        assertApproxEqRel(uint256(price.unwrap()), 2e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_phaseShifted_atPi() public view {
        // p(π) = sin(π + π/2) + 2 = sin(3π/2) + 2 = -1 + 2 = 1
        SD59x18 price = SinLib.spotPrice(phaseShiftedParams, sd(PI));
        assertApproxEqRel(uint256(price.unwrap()), 1e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_phaseShifted_leadsDefaultByHalfPi() public view {
        // sin(s + π/2) = cos(s), so phase-shifted at s should equal default at s + π/2
        // p_phase(s) = sin(s + π/2) + 2
        // p_default(s + π/2) = sin(s + π/2) + 2
        SD59x18 s = sd(1e18);
        SD59x18 pPhase = SinLib.spotPrice(phaseShiftedParams, s);
        SD59x18 pDefault = SinLib.spotPrice(defaultParams, s + sd(HALF_PI));

        assertApproxEqRel(uint256(pPhase.unwrap()), uint256(pDefault.unwrap()), TRIG_TOLERANCE);
    }

    // ── High frequency: p(s) = sin(10·s) + 2 ───────────────────

    function test_spotPrice_highFreq_atZero() public view {
        // p(0) = sin(0) + 2 = 2
        SD59x18 price = SinLib.spotPrice(highFreqParams, sd(0));
        assertEq(price.unwrap(), 2e18);
    }

    function test_spotPrice_highFreq_atPiOver20() public view {
        // p(π/20) = sin(10·π/20) + 2 = sin(π/2) + 2 = 3
        // π/20 ≈ 0.15707963e18
        SD59x18 price = SinLib.spotPrice(highFreqParams, sd(HALF_PI / 10));
        assertApproxEqRel(uint256(price.unwrap()), 3e18, TRIG_TOLERANCE);
    }

    function test_spotPrice_highFreq_oscillatesFaster() public view {
        // With w=10, one full cycle takes 2π/10 ≈ 0.6283 supply units
        // Check price at s=0 and s=2π/10 are approximately equal (full cycle)
        SD59x18 period = sd(2 * PI / 10);
        SD59x18 p0 = SinLib.spotPrice(highFreqParams, sd(0));
        SD59x18 pCycle = SinLib.spotPrice(highFreqParams, period);

        assertApproxEqRel(uint256(p0.unwrap()), uint256(pCycle.unwrap()), TRIG_TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
          INTEGRATE: ∫(a·sin(w·s + phi) + b) ds
                   = -a/w · cos(w·s + phi) + b·s
    //////////////////////////////////////////////////////////////*/

    // ── Default: ∫ (sin(s) + 2) ds ──────────────────────────────

    function test_integrate_default_zeroToZero() public view {
        SD59x18 area = SinLib.integrate(defaultParams, sd(0), sd(0));
        assertEq(area.unwrap(), 0);
    }

    function test_integrate_default_zeroToHalfPi() public view {
        // F(s) = -cos(s) + 2s
        // F(π/2) = -cos(π/2) + 2·(π/2) = -0 + π ≈ 3.14159
        // F(0)   = -cos(0) + 0 = -1
        // area = π - (-1) = π + 1 ≈ 4.14159
        SD59x18 area = SinLib.integrate(defaultParams, sd(0), sd(HALF_PI));
        assertApproxEqRel(uint256(area.unwrap()), uint256(PI + 1e18), TRIG_TOLERANCE);
    }

    function test_integrate_default_zeroToPi() public view {
        // F(π)  = -cos(π) + 2π = 1 + 2π ≈ 7.28318
        // F(0)  = -1
        // area = 1 + 2π - (-1) = 2 + 2π ≈ 8.28318
        SD59x18 area = SinLib.integrate(defaultParams, sd(0), sd(PI));
        uint256 expected = uint256(2e18 + 2 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    function test_integrate_default_zeroToTwoPi() public view {
        // Over a full cycle, ∫sin(s)ds = 0, so only the b·s term remains
        // F(2π) = -cos(2π) + 2·(2π) = -1 + 4π
        // F(0)  = -cos(0) + 0 = -1
        // area = (-1 + 4π) - (-1) = 4π ≈ 12.56637
        SD59x18 area = SinLib.integrate(defaultParams, sd(0), sd(2 * PI));
        uint256 expected = uint256(4 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    function test_integrate_default_fullCycleEqualsOffsetOnly() public view {
        // Over any full cycle [s, s + 2π], the sin integral cancels to 0
        // So the area equals b · 2π = 2 · 2π = 4π
        SD59x18 s = sd(1e18);
        SD59x18 area = SinLib.integrate(defaultParams, s, s + sd(2 * PI));
        uint256 expected = uint256(4 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    // ── High offset: ∫ (sin(s) + 10) ds ─────────────────────────

    function test_integrate_highOffset_zeroToTwoPi() public view {
        // Over full cycle, sin cancels: area = 10 · 2π = 20π ≈ 62.8318
        SD59x18 area = SinLib.integrate(highOffsetParams, sd(0), sd(2 * PI));
        uint256 expected = uint256(20 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    function test_integrate_highOffset_exceedsDefault() public view {
        // Same sin component, but b=10 vs b=2, so highOffset area is always larger
        SD59x18 areaDefault = SinLib.integrate(defaultParams, sd(0), sd(3e18));
        SD59x18 areaHigh = SinLib.integrate(highOffsetParams, sd(0), sd(3e18));

        assertTrue(areaHigh > areaDefault);
        // Difference should be (10 - 2) · 3 = 24
        assertApproxEqRel(uint256((areaHigh - areaDefault).unwrap()), 24e18, TRIG_TOLERANCE);
    }

    // ── Scaled amplitude: ∫ (3·sin(s) + 5) ds ──────────────────

    function test_integrate_scaledAmplitude_zeroToTwoPi() public view {
        // Over full cycle: 3·∫sin = 0, so area = 5 · 2π = 10π ≈ 31.4159
        SD59x18 area = SinLib.integrate(scaledAmplitudeParams, sd(0), sd(2 * PI));
        uint256 expected = uint256(10 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    function test_integrate_scaledAmplitude_zeroToHalfPi() public view {
        // F(s) = -3·cos(s) + 5s
        // F(π/2) = -3·cos(π/2) + 5·(π/2) = 0 + 5π/2 ≈ 7.8540
        // F(0)   = -3·cos(0) + 0 = -3
        // area = 5π/2 - (-3) = 5π/2 + 3 ≈ 10.8540
        SD59x18 area = SinLib.integrate(scaledAmplitudeParams, sd(0), sd(HALF_PI));
        uint256 expected = uint256(5 * HALF_PI + 3e18);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    // ── Phase-shifted: ∫ (sin(s + π/2) + 2) ds ─────────────────

    function test_integrate_phaseShifted_zeroToTwoPi() public view {
        // Over full cycle, sin cancels regardless of phase: area = 2 · 2π = 4π
        SD59x18 area = SinLib.integrate(phaseShiftedParams, sd(0), sd(2 * PI));
        uint256 expected = uint256(4 * PI);
        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀^(2π) = ∫₀^π + ∫_π^(2π)
        SD59x18 whole = SinLib.integrate(defaultParams, sd(0), sd(2 * PI));
        SD59x18 part1 = SinLib.integrate(defaultParams, sd(0), sd(PI));
        SD59x18 part2 = SinLib.integrate(defaultParams, sd(PI), sd(2 * PI));

        assertApproxEqRel(uint256(whole.unwrap()), uint256((part1 + part2).unwrap()), TRIG_TOLERANCE);
    }

    function test_integrate_additivity_threeWaySplit() public view {
        // ∫₀^(2π) = ∫₀^(π/2) + ∫_(π/2)^π + ∫_π^(2π)
        SD59x18 whole = SinLib.integrate(defaultParams, sd(0), sd(2 * PI));
        SD59x18 p1 = SinLib.integrate(defaultParams, sd(0), sd(HALF_PI));
        SD59x18 p2 = SinLib.integrate(defaultParams, sd(HALF_PI), sd(PI));
        SD59x18 p3 = SinLib.integrate(defaultParams, sd(PI), sd(2 * PI));

        assertApproxEqRel(uint256(whole.unwrap()), uint256((p1 + p2 + p3).unwrap()), TRIG_TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For tiny δ: ∫(s, s+δ) ≈ p(s)·δ
        SD59x18 s = sd(1e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = SinLib.spotPrice(defaultParams, s);
        SD59x18 area = SinLib.integrate(defaultParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), TRIG_TOLERANCE);
    }

    function test_spotIntegralConsistency_scaledAmplitude() public view {
        SD59x18 s = sd(2e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = SinLib.spotPrice(scaledAmplitudeParams, s);
        SD59x18 area = SinLib.integrate(scaledAmplitudeParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), TRIG_TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                      FUZZ: UNIVERSAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzz_integrate_fullCycleEqualsOffset(uint256 start) public view {
        // Over any full cycle, the sin component cancels: area = b · 2π
        start = bound(start, 1e18, 100e18);
        SD59x18 s = sd(int256(start));

        SD59x18 area = SinLib.integrate(defaultParams, s, s + sd(2 * PI));
        uint256 expected = uint256(4 * PI); // b=2, so 2 · 2π = 4π

        assertApproxEqRel(uint256(area.unwrap()), expected, TRIG_TOLERANCE);
    }

    function testFuzz_integrate_nonNegative(uint256 from, uint256 to) public view {
        // price >= 1 everywhere (min = sin_min + b = -1 + 2 = 1), so integral is non-negative
        from = bound(from, 1e18, 50e18);
        to = bound(to, from, 100e18);

        SD59x18 area = SinLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        assertTrue(area >= sd(0));
    }

    function testFuzz_integrate_monotonicity(uint256 start, uint256 end1, uint256 end2) public view {
        // Wider range → larger area (since price is always >= 1)
        start = bound(start, 1e18, 30e18);
        end1 = bound(end1, start, 60e18);
        end2 = bound(end2, end1, 90e18);

        SD59x18 area1 = SinLib.integrate(defaultParams, sd(int256(start)), sd(int256(end1)));
        SD59x18 area2 = SinLib.integrate(defaultParams, sd(int256(start)), sd(int256(end2)));

        assertTrue(area2 >= area1);
    }
}