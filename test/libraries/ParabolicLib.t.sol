// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { ParabolicLib } from "../../src/libraries/ParabolicLib.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

contract ParabolicLibTest is BaseTest, Helpers {
    // Default params: p(s) = 1·s² + 0·s + 0
    // Pure quadratic — integral is s³/3, easy to verify by hand
    bytes internal defaultParams;

    // Full quadratic: p(s) = 2·s² + 3·s + 5
    // Exercises all three terms in both spotPrice and the antiderivative
    bytes internal fullParams;

    // Linear-only via parabolic: p(s) = 0·s² + 4·s + 1
    // a=0 degenerates to linear — catches division issues in a*s³/3 when a=0
    bytes internal linearDegenerateParams;

    // Constant-only via parabolic: p(s) = 0·s² + 0·s + 7
    // Fully degenerate — integral should be exactly 7·(sTo - sFrom)
    bytes internal constantParams;

    // Small coefficient: p(s) = 0.001·s² + 0·s + 1
    // Tiny `a` with large `s` values tests fixed-point precision on the s³/3 term
    bytes internal smallCoeffParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = s²
        defaultParams = abi.encode(Types.ParabolicParams({ a: 1e18, b: 0, c: 0 }));

        // p(s) = 2s² + 3s + 5
        fullParams = abi.encode(Types.ParabolicParams({ a: 2e18, b: 3e18, c: 5e18 }));

        // p(s) = 4s + 1
        linearDegenerateParams = abi.encode(Types.ParabolicParams({ a: 0, b: 4e18, c: 1e18 }));

        // p(s) = 7
        constantParams = abi.encode(Types.ParabolicParams({ a: 0, b: 0, c: 7e18 }));

        // p(s) = 0.001·s² + 1
        smallCoeffParams = abi.encode(Types.ParabolicParams({ a: 0.001e18, b: 0, c: 1e18 }));

        // Reusable segment: PARABOLIC over [0, 1000e18] with default params
        defaultSegments.push(_createParabolicSegment(0, 1000e18));
    }
}