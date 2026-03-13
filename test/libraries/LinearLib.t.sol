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
import { LinearLib } from "../../src/libraries/LinearLib.sol";

contract LinearLibTest is BaseTest, Helpers {
    // Default params: p(s) = 1·s + 0
    bytes internal defaultParams;

    // Custom params: p(s) = 2·s + 3
    bytes internal slopeInterceptParams;

    // Flat price: p(s) = 0·s + 5  (constant price = 5)
    bytes internal flatParams;

    // Negative slope: p(s) = -0.5·s + 100 (decreasing price)
    bytes internal negSlopeParams;

    // Single-segment array for PriceLib-level checks
    Types.PiecewiseSegment[] internal defaultSegments;

    function setUp() public override {
        super.setUp();

        // p(s) = s
        defaultParams = abi.encode(Types.LinearParams({ m: 1e18, b: 0 }));

        // p(s) = 2s + 3
        slopeInterceptParams = abi.encode(Types.LinearParams({ m: 2e18, b: 3e18 }));

        // p(s) = 5  (constant)
        flatParams = abi.encode(Types.LinearParams({ m: 0, b: 5e18 }));

        // p(s) = -0.5s + 100
        negSlopeParams = abi.encode(Types.LinearParams({ m: -0.5e18, b: 100e18 }));

        // Reusable segment: LINEAR over [0, 1000e18] with default params
        defaultSegments.push(_createLinearSegment(0, 1000e18));
    }
}