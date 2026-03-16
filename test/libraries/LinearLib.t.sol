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

    /*//////////////////////////////////////////////////////////////
                  INTEGRATE: ∫(m·s + b)ds = m·s²/2 + b·s
    //////////////////////////////////////////////////////////////*/

    function test_integrate_default_zeroToTen() public view {
        // ∫₀¹⁰ s ds = 10²/2 = 50
        SD59x18 area = LinearLib.integrate(defaultParams, sd(0), sd(10e18));
        assertEq(area.unwrap(), 50e18);
    }

    function test_integrate_default_zeroToHundred() public view {
        // ∫₀¹⁰⁰ s ds = 100²/2 = 5000
        SD59x18 area = LinearLib.integrate(defaultParams, sd(0), sd(100e18));
        assertEq(area.unwrap(), 5000e18);
    }

    function test_integrate_default_nonZeroStart() public view {
        // ∫₁₀²⁰ s ds = 20²/2 - 10²/2 = 200 - 50 = 150
        SD59x18 area = LinearLib.integrate(defaultParams, sd(10e18), sd(20e18));
        assertEq(area.unwrap(), 150e18);
    }

    function test_integrate_slopeIntercept_zeroToTen() public view {
        // ∫₀¹⁰ (2s + 3) ds = [s² + 3s]₀¹⁰ = 100 + 30 = 130
        SD59x18 area = LinearLib.integrate(slopeInterceptParams, sd(0), sd(10e18));
        assertEq(area.unwrap(), 130e18);
    }

    function test_integrate_slopeIntercept_fiveToFifteen() public view {
        // ∫₅¹⁵ (2s + 3) ds = [s² + 3s]₅¹⁵ = (225 + 45) - (25 + 15) = 270 - 40 = 230
        SD59x18 area = LinearLib.integrate(slopeInterceptParams, sd(5e18), sd(15e18));
        assertEq(area.unwrap(), 230e18);
    }

    function test_integrate_flat_zeroToHundred() public view {
        // ∫₀¹⁰⁰ 5 ds = 5 · 100 = 500
        SD59x18 area = LinearLib.integrate(flatParams, sd(0), sd(100e18));
        assertEq(area.unwrap(), 500e18);
    }

    function test_integrate_flat_tenToFifty() public view {
        // ∫₁₀⁵⁰ 5 ds = 5 · 40 = 200
        SD59x18 area = LinearLib.integrate(flatParams, sd(10e18), sd(50e18));
        assertEq(area.unwrap(), 200e18);
    }

    function test_integrate_negSlope_zeroToHundred() public view {
        // ∫₀¹⁰⁰ (-0.5s + 100) ds = [-0.25s² + 100s]₀¹⁰⁰ = -2500 + 10000 = 7500
        SD59x18 area = LinearLib.integrate(negSlopeParams, sd(0), sd(100e18));
        assertEq(area.unwrap(), 7500e18);
    }

    function test_integrate_zeroWidth_returnsZero() public view {
        // ∫₁₀¹⁰ anything ds = 0
        SD59x18 area = LinearLib.integrate(defaultParams, sd(10e18), sd(10e18));
        assertEq(area.unwrap(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀³⁰ = ∫₀¹⁰ + ∫₁₀³⁰
        SD59x18 whole = LinearLib.integrate(defaultParams, sd(0), sd(30e18));
        SD59x18 part1 = LinearLib.integrate(defaultParams, sd(0), sd(10e18));
        SD59x18 part2 = LinearLib.integrate(defaultParams, sd(10e18), sd(30e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_slopeIntercept() public view {
        // ∫₀²⁰ = ∫₀⁷ + ∫₇²⁰
        SD59x18 whole = LinearLib.integrate(slopeInterceptParams, sd(0), sd(20e18));
        SD59x18 part1 = LinearLib.integrate(slopeInterceptParams, sd(0), sd(7e18));
        SD59x18 part2 = LinearLib.integrate(slopeInterceptParams, sd(7e18), sd(20e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_threeWaySplit() public view {
        // ∫₀³⁰ = ∫₀¹⁰ + ∫₁₀²⁰ + ∫₂₀³⁰
        SD59x18 whole = LinearLib.integrate(defaultParams, sd(0), sd(30e18));
        SD59x18 p1 = LinearLib.integrate(defaultParams, sd(0), sd(10e18));
        SD59x18 p2 = LinearLib.integrate(defaultParams, sd(10e18), sd(20e18));
        SD59x18 p3 = LinearLib.integrate(defaultParams, sd(20e18), sd(30e18));
        assertEq(whole.unwrap(), (p1 + p2 + p3).unwrap());
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For a tiny δ, integrate(s, s+δ) ≈ spotPrice(s) · δ
        SD59x18 s = sd(50e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = LinearLib.spotPrice(defaultParams, s);
        SD59x18 area = LinearLib.integrate(defaultParams, s, s + delta);

        // spot · δ (manual SD59x18 mul: spot * delta / 1e18)
        SD59x18 approx = spot * delta;

        // Should be very close — within 0.1%
        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function test_spotIntegralConsistency_slopeIntercept() public view {
        SD59x18 s = sd(25e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = LinearLib.spotPrice(slopeInterceptParams, s);
        SD59x18 area = LinearLib.integrate(slopeInterceptParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    
}