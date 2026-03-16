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
}