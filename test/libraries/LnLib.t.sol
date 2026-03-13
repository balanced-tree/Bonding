// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { LnLib } from "../../src/libraries/LnLib.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

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
}