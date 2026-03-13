// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { ExponentialLib } from "../../src/libraries/ExponentialLib.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

contract ExponentialLibTest is BaseTest, Helpers {
    // Default params: p(s) = 1·e^(1·s) + 0
    // Standard exponential — grows fast, useful baseline
    bytes internal defaultParams;

    // Offset params: p(s) = 1·e^(1·s) + 5
    // Non-zero `b` ensures the b·s term in the integral is exercised
    bytes internal offsetParams;

    // Slow growth: p(s) = 1·e^(0.01·s) + 0
    // Small k makes growth nearly linear over small ranges — good for precision checks
    bytes internal slowGrowthParams;

    // Scaled amplitude: p(s) = 3·e^(0.5·s) + 2
    // Exercises the a/k ratio in the antiderivative (a/k = 6)
    bytes internal scaledParams;

    // Fractional amplitude: p(s) = 0.1·e^(1·s) + 0
    // Small `a` tests that the a/k division doesn't lose precision
    bytes internal smallAmpParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = e^s
        defaultParams = abi.encode(Types.ExponentialParams({ a: 1e18, k: 1e18, b: 0 }));

        // p(s) = e^s + 5
        offsetParams = abi.encode(Types.ExponentialParams({ a: 1e18, k: 1e18, b: 5e18 }));

        // p(s) = e^(0.01·s)
        slowGrowthParams = abi.encode(Types.ExponentialParams({ a: 1e18, k: 0.01e18, b: 0 }));

        // p(s) = 3·e^(0.5·s) + 2
        scaledParams = abi.encode(Types.ExponentialParams({ a: 3e18, k: 0.5e18, b: 2e18 }));

        // p(s) = 0.1·e^s
        smallAmpParams = abi.encode(Types.ExponentialParams({ a: 0.1e18, k: 1e18, b: 0 }));

        // Reusable segment: EXPONENTIAL over [0, 1000e18] with default params
        defaultSegments.push(_createExponentialSegment(0, 1000e18));
    }
}