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
import { SigmoidLib } from "../../src/libraries/SigmoidLib.sol";

contract SigmoidLibTest is BaseTest, Helpers {
    // Default params: p(s) = 10 / (1 + e^(-1·(s - 5))) + 0
    // Classic S-curve: maxVal=10, midpoint at s=5, steepness k=1, no offset
    bytes internal defaultParams;

    // With offset: p(s) = 10 / (1 + e^(-1·(s - 5))) + 3
    // Non-zero b shifts the entire curve up — tests the b·s term in the integral
    bytes internal offsetParams;

    // Steep sigmoid: p(s) = 10 / (1 + e^(-5·(s - 5))) + 0
    // k=5 makes the transition very sharp — nearly a step function around s0
    bytes internal steepParams;

    // Gentle sigmoid: p(s) = 10 / (1 + e^(-0.1·(s - 50))) + 0
    // k=0.1 spreads the transition over a wide supply range, midpoint at s=50
    bytes internal gentleParams;

    // Large maxVal: p(s) = 100 / (1 + e^(-1·(s - 10))) + 0
    // High maxVal with shifted midpoint — exercises larger maxVal/k ratio in antiderivative
    bytes internal largeMaxValParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = 10 / (1 + e^(-(s - 5)))
        defaultParams = abi.encode(Types.SigmoidParams({ maxVal: 10e18, k: 1e18, s0: 5e18, b: 0 }));

        // p(s) = 10 / (1 + e^(-(s - 5))) + 3
        offsetParams = abi.encode(Types.SigmoidParams({ maxVal: 10e18, k: 1e18, s0: 5e18, b: 3e18 }));

        // p(s) = 10 / (1 + e^(-5·(s - 5)))
        steepParams = abi.encode(Types.SigmoidParams({ maxVal: 10e18, k: 5e18, s0: 5e18, b: 0 }));

        // p(s) = 10 / (1 + e^(-0.1·(s - 50)))
        gentleParams = abi.encode(Types.SigmoidParams({ maxVal: 10e18, k: 0.1e18, s0: 50e18, b: 0 }));

        // p(s) = 100 / (1 + e^(-(s - 10)))
        largeMaxValParams = abi.encode(Types.SigmoidParams({ maxVal: 100e18, k: 1e18, s0: 10e18, b: 0 }));

        // Reusable segment: SIGMOID over [0, 1000e18] with default params
        defaultSegments.push(_createSigmoidSegment(0, 1000e18));
    }
}