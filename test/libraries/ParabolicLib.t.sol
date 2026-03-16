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
import { ParabolicLib } from "../../src/libraries/ParabolicLib.sol";

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

    /*//////////////////////////////////////////////////////////////
                SPOT PRICE: p(s) = a·s² + b·s + c
    //////////////////////////////////////////////////////////////*/

    // ── Default: p(s) = s² ──────────────────────────────────────

    function test_spotPrice_default_atZero() public view {
        // p(0) = 0
        SD59x18 price = ParabolicLib.spotPrice(defaultParams, sd(0));
        assertEq(price.unwrap(), 0);
    }

    function test_spotPrice_default_atOne() public view {
        // p(1) = 1
        SD59x18 price = ParabolicLib.spotPrice(defaultParams, sd(1e18));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_default_atTen() public view {
        // p(10) = 100
        SD59x18 price = ParabolicLib.spotPrice(defaultParams, sd(10e18));
        assertEq(price.unwrap(), 100e18);
    }

    function test_spotPrice_default_atHundred() public view {
        // p(100) = 10000
        SD59x18 price = ParabolicLib.spotPrice(defaultParams, sd(100e18));
        assertEq(price.unwrap(), 10_000e18);
    }

    // ── Full quadratic: p(s) = 2s² + 3s + 5 ────────────────────

    function test_spotPrice_full_atZero() public view {
        // p(0) = 0 + 0 + 5 = 5
        SD59x18 price = ParabolicLib.spotPrice(fullParams, sd(0));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_full_atOne() public view {
        // p(1) = 2 + 3 + 5 = 10
        SD59x18 price = ParabolicLib.spotPrice(fullParams, sd(1e18));
        assertEq(price.unwrap(), 10e18);
    }

    function test_spotPrice_full_atFive() public view {
        // p(5) = 2·25 + 3·5 + 5 = 50 + 15 + 5 = 70
        SD59x18 price = ParabolicLib.spotPrice(fullParams, sd(5e18));
        assertEq(price.unwrap(), 70e18);
    }

    function test_spotPrice_full_atTen() public view {
        // p(10) = 2·100 + 3·10 + 5 = 200 + 30 + 5 = 235
        SD59x18 price = ParabolicLib.spotPrice(fullParams, sd(10e18));
        assertEq(price.unwrap(), 235e18);
    }

    // ── Linear degenerate: p(s) = 4s + 1 ────────────────────────

    function test_spotPrice_linearDegenerate_atZero() public view {
        // p(0) = 0 + 1 = 1
        SD59x18 price = ParabolicLib.spotPrice(linearDegenerateParams, sd(0));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_linearDegenerate_atTen() public view {
        // p(10) = 40 + 1 = 41
        SD59x18 price = ParabolicLib.spotPrice(linearDegenerateParams, sd(10e18));
        assertEq(price.unwrap(), 41e18);
    }

    function test_spotPrice_linearDegenerate_atFifty() public view {
        // p(50) = 200 + 1 = 201
        SD59x18 price = ParabolicLib.spotPrice(linearDegenerateParams, sd(50e18));
        assertEq(price.unwrap(), 201e18);
    }

    // ── Constant: p(s) = 7 ──────────────────────────────────────

    function test_spotPrice_constant_isAlwaysSeven() public view {
        assertEq(ParabolicLib.spotPrice(constantParams, sd(0)).unwrap(), 7e18);
        assertEq(ParabolicLib.spotPrice(constantParams, sd(1e18)).unwrap(), 7e18);
        assertEq(ParabolicLib.spotPrice(constantParams, sd(100e18)).unwrap(), 7e18);
        assertEq(ParabolicLib.spotPrice(constantParams, sd(999e18)).unwrap(), 7e18);
    }

    // ── Small coefficient: p(s) = 0.001·s² + 1 ─────────────────

    function test_spotPrice_smallCoeff_atZero() public view {
        // p(0) = 0 + 1 = 1
        SD59x18 price = ParabolicLib.spotPrice(smallCoeffParams, sd(0));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_smallCoeff_atHundred() public view {
        // p(100) = 0.001·10000 + 1 = 10 + 1 = 11
        SD59x18 price = ParabolicLib.spotPrice(smallCoeffParams, sd(100e18));
        assertEq(price.unwrap(), 11e18);
    }

    function test_spotPrice_smallCoeff_atThousand() public view {
        // p(1000) = 0.001·1000000 + 1 = 1000 + 1 = 1001
        SD59x18 price = ParabolicLib.spotPrice(smallCoeffParams, sd(1000e18));
        assertEq(price.unwrap(), 1001e18);
    }

    // ── Relational tests ────────────────────────────────────────

    function test_spotPrice_default_growsFasterThanLinear() public view {
        // p_parabolic(s) = s² grows faster than p_linear(s) = s for s > 1
        SD59x18 s = sd(10e18);
        SD59x18 pParabolic = ParabolicLib.spotPrice(defaultParams, s);
        // linear: p(10) = 10
        assertTrue(pParabolic.unwrap() > 10e18);
    }

    function test_spotPrice_full_exceedsDefault() public view {
        // p_full(s) = 2s² + 3s + 5 > p_default(s) = s² for all s > 0
        SD59x18 s = sd(5e18);
        SD59x18 pFull = ParabolicLib.spotPrice(fullParams, s);
        SD59x18 pDefault = ParabolicLib.spotPrice(defaultParams, s);
        assertTrue(pFull > pDefault);
    }

    // ── Fuzz ────────────────────────────────────────────────────

    function testFuzz_spotPrice_default_isSquare(uint256 s) public view {
        // p(s) = s² for default params
        s = bound(s, 0, 1000e18);
        SD59x18 price = ParabolicLib.spotPrice(defaultParams, sd(int256(s)));
        // s² in SD59x18: s * s / 1e18
        int256 expected = int256(s) * int256(s) / 1e18;
        assertEq(price.unwrap(), expected);
    }

    function testFuzz_spotPrice_constant_isAlwaysSeven(uint256 s) public view {
        s = bound(s, 0, 1000e18);
        SD59x18 price = ParabolicLib.spotPrice(constantParams, sd(int256(s)));
        assertEq(price.unwrap(), 7e18);
    }

    function testFuzz_spotPrice_linearDegenerate_matchesLinear(uint256 s) public view {
        // p(s) = 4s + 1
        s = bound(s, 0, 1000e18);
        SD59x18 price = ParabolicLib.spotPrice(linearDegenerateParams, sd(int256(s)));
        int256 expected = 4e18 * int256(s) / 1e18 + 1e18;
        assertEq(price.unwrap(), expected);
    }
}