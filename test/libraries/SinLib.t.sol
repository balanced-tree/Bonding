// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { SinLib } from "../../src/libraries/SinLib.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

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
}