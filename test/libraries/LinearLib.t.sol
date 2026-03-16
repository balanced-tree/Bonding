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

    /*//////////////////////////////////////////////////////////////
                      SPOT PRICE: p(s) = m·s + b
    //////////////////////////////////////////////////////////////*/

    function test_spotPrice_default_atZero() public view {
        // p(0) = 1·0 + 0 = 0
        SD59x18 price = LinearLib.spotPrice(defaultParams, sd(0));
        assertEq(price.unwrap(), 0);
    }

    function test_spotPrice_default_atOne() public view {
        // p(1) = 1·1 + 0 = 1
        SD59x18 price = LinearLib.spotPrice(defaultParams, sd(1e18));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_default_atLargeSupply() public view {
        // p(500) = 500
        SD59x18 price = LinearLib.spotPrice(defaultParams, sd(500e18));
        assertEq(price.unwrap(), 500e18);
    }

    function test_spotPrice_slopeIntercept_atZero() public view {
        // p(0) = 2·0 + 3 = 3
        SD59x18 price = LinearLib.spotPrice(slopeInterceptParams, sd(0));
        assertEq(price.unwrap(), 3e18);
    }

    function test_spotPrice_slopeIntercept_atTen() public view {
        // p(10) = 2·10 + 3 = 23
        SD59x18 price = LinearLib.spotPrice(slopeInterceptParams, sd(10e18));
        assertEq(price.unwrap(), 23e18);
    }

    function test_spotPrice_flat_isConstant() public view {
        // p(s) = 5 for any s
        assertEq(LinearLib.spotPrice(flatParams, sd(0)).unwrap(), 5e18);
        assertEq(LinearLib.spotPrice(flatParams, sd(100e18)).unwrap(), 5e18);
        assertEq(LinearLib.spotPrice(flatParams, sd(999e18)).unwrap(), 5e18);
    }

    function test_spotPrice_negSlope_atZero() public view {
        // p(0) = -0.5·0 + 100 = 100
        SD59x18 price = LinearLib.spotPrice(negSlopeParams, sd(0));
        assertEq(price.unwrap(), 100e18);
    }

    function test_spotPrice_negSlope_atHundred() public view {
        // p(100) = -0.5·100 + 100 = 50
        SD59x18 price = LinearLib.spotPrice(negSlopeParams, sd(100e18));
        assertEq(price.unwrap(), 50e18);
    }

    function test_spotPrice_negSlope_atTwoHundred() public view {
        // p(200) = -0.5·200 + 100 = 0
        SD59x18 price = LinearLib.spotPrice(negSlopeParams, sd(200e18));
        assertEq(price.unwrap(), 0);
    }

    
}