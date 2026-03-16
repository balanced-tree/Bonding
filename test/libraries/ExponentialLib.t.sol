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
import { ExponentialLib } from "../../src/libraries/ExponentialLib.sol";

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

    /*//////////////////////////////////////////////////////////////
                SPOT PRICE: p(s) = a·e^(k·s) + b
    //////////////////////////////////////////////////////////////*/

    // ── Default: p(s) = e^s ───────────────────────────────────

    function test_spotPrice_default_atZero() public view {
        // p(0) = e^0 = 1 (exact — exp(0) = 1e18 in SD59x18)
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(0));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_default_atOne() public view {
        // p(1) = e ≈ 2.718281828459045...
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(1e18));
        assertApproxEqRel(uint256(price.unwrap()), 2_718281828459045235, 0.0001e18);
    }

    function test_spotPrice_default_atTwo() public view {
        // p(2) = e² ≈ 7.389056098930650...
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(2e18));
        assertApproxEqRel(uint256(price.unwrap()), 7_389056098930650227, 0.0001e18);
    }

    function test_spotPrice_default_atFive() public view {
        // p(5) = e⁵ ≈ 148.413159102576603...
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(5e18));
        assertApproxEqRel(uint256(price.unwrap()), 148_413159102576603421, 0.0001e18);
    }

    function test_spotPrice_default_atTen() public view {
        // p(10) = e¹⁰ ≈ 22026.4657948...
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(10e18));
        assertApproxEqRel(uint256(price.unwrap()), 22026_465794806716000000, 0.01e18);
    }

    // ── Offset: p(s) = e^s + 5 ───────────────────────────────

    function test_spotPrice_offset_atZero() public view {
        // p(0) = e^0 + 5 = 1 + 5 = 6 (exact)
        SD59x18 price = ExponentialLib.spotPrice(offsetParams, sd(0));
        assertEq(price.unwrap(), 6e18);
    }

    function test_spotPrice_offset_atOne() public view {
        // p(1) = e + 5 ≈ 7.718281828...
        SD59x18 price = ExponentialLib.spotPrice(offsetParams, sd(1e18));
        assertApproxEqRel(uint256(price.unwrap()), 7_718281828459045235, 0.0001e18);
    }

    function test_spotPrice_offset_atTwo() public view {
        // p(2) = e² + 5 ≈ 12.389056099...
        SD59x18 price = ExponentialLib.spotPrice(offsetParams, sd(2e18));
        assertApproxEqRel(uint256(price.unwrap()), 12_389056098930650227, 0.0001e18);
    }

    // ── Slow growth: p(s) = e^(0.01·s) ───────────────────────

    function test_spotPrice_slowGrowth_atZero() public view {
        // p(0) = e^0 = 1 (exact)
        SD59x18 price = ExponentialLib.spotPrice(slowGrowthParams, sd(0));
        assertEq(price.unwrap(), 1e18);
    }

    function test_spotPrice_slowGrowth_atHundred() public view {
        // p(100) = e^(0.01·100) = e^1 = e ≈ 2.718281828...
        SD59x18 price = ExponentialLib.spotPrice(slowGrowthParams, sd(100e18));
        assertApproxEqRel(uint256(price.unwrap()), 2_718281828459045235, 0.0001e18);
    }

    function test_spotPrice_slowGrowth_atThousand() public view {
        // p(1000) = e^(0.01·1000) = e^10 ≈ 22026.4657948...
        SD59x18 price = ExponentialLib.spotPrice(slowGrowthParams, sd(1000e18));
        assertApproxEqRel(uint256(price.unwrap()), 22026_465794806716000000, 0.01e18);
    }

    // ── Scaled: p(s) = 3·e^(0.5·s) + 2 ──────────────────────

    function test_spotPrice_scaled_atZero() public view {
        // p(0) = 3·e^0 + 2 = 3 + 2 = 5 (exact)
        SD59x18 price = ExponentialLib.spotPrice(scaledParams, sd(0));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_scaled_atTwo() public view {
        // p(2) = 3·e^(0.5·2) + 2 = 3·e + 2 ≈ 3·2.71828... + 2 ≈ 10.15485...
        SD59x18 price = ExponentialLib.spotPrice(scaledParams, sd(2e18));
        assertApproxEqRel(uint256(price.unwrap()), 10_154845485377135705, 0.0001e18);
    }

    function test_spotPrice_scaled_atFour() public view {
        // p(4) = 3·e^2 + 2 ≈ 3·7.38906... + 2 ≈ 24.16717...
        SD59x18 price = ExponentialLib.spotPrice(scaledParams, sd(4e18));
        assertApproxEqRel(uint256(price.unwrap()), 24_167168296791950681, 0.0001e18);
    }

    function test_spotPrice_scaled_atTen() public view {
        // p(10) = 3·e^5 + 2 ≈ 3·148.413... + 2 ≈ 447.240...
        SD59x18 price = ExponentialLib.spotPrice(scaledParams, sd(10e18));
        assertApproxEqRel(uint256(price.unwrap()), 447_239477307729810263, 0.01e18);
    }

    // ── Small amplitude: p(s) = 0.1·e^s ──────────────────────

    function test_spotPrice_smallAmp_atZero() public view {
        // p(0) = 0.1·e^0 = 0.1 (exact)
        SD59x18 price = ExponentialLib.spotPrice(smallAmpParams, sd(0));
        assertEq(price.unwrap(), 0.1e18);
    }

    function test_spotPrice_smallAmp_atOne() public view {
        // p(1) = 0.1·e ≈ 0.271828...
        SD59x18 price = ExponentialLib.spotPrice(smallAmpParams, sd(1e18));
        assertApproxEqRel(uint256(price.unwrap()), 271828182845904523, 0.0001e18);
    }

    function test_spotPrice_smallAmp_atFive() public view {
        // p(5) = 0.1·e⁵ ≈ 14.841316...
        SD59x18 price = ExponentialLib.spotPrice(smallAmpParams, sd(5e18));
        assertApproxEqRel(uint256(price.unwrap()), 14_841315910257660342, 0.0001e18);
    }

    // ── Relational tests ──────────────────────────────────────

    function test_spotPrice_default_isStrictlyIncreasing() public view {
        // e^s is strictly increasing: p(1) < p(2) < p(5)
        SD59x18 p1 = ExponentialLib.spotPrice(defaultParams, sd(1e18));
        SD59x18 p2 = ExponentialLib.spotPrice(defaultParams, sd(2e18));
        SD59x18 p5 = ExponentialLib.spotPrice(defaultParams, sd(5e18));
        assertTrue(p1 < p2);
        assertTrue(p2 < p5);
    }

    function test_spotPrice_offset_exceedsDefault() public view {
        // p_offset(s) = e^s + 5 > p_default(s) = e^s for all s
        SD59x18 s = sd(3e18);
        SD59x18 pOffset = ExponentialLib.spotPrice(offsetParams, s);
        SD59x18 pDefault = ExponentialLib.spotPrice(defaultParams, s);
        assertEq((pOffset - pDefault).unwrap(), 5e18);
    }

    function test_spotPrice_smallAmp_isScaledDefault() public view {
        // p_smallAmp(s) = 0.1·e^s = 0.1 · p_default(s)
        SD59x18 s = sd(3e18);
        SD59x18 pSmall = ExponentialLib.spotPrice(smallAmpParams, s);
        SD59x18 pDefault = ExponentialLib.spotPrice(defaultParams, s);
        // 0.1 · pDefault — allow tiny rounding tolerance
        assertApproxEqRel(uint256(pSmall.unwrap()), uint256(pDefault.unwrap()) / 10, 0.0001e18);
    }

    function test_spotPrice_slowGrowth_matchesDefault_atEquivalentPoint() public view {
        // slowGrowth p(100) = e^(0.01·100) = e^1 should match default p(1) = e^1
        SD59x18 pSlow = ExponentialLib.spotPrice(slowGrowthParams, sd(100e18));
        SD59x18 pDefault = ExponentialLib.spotPrice(defaultParams, sd(1e18));
        assertApproxEqRel(uint256(pSlow.unwrap()), uint256(pDefault.unwrap()), 0.0001e18);
    }

    // ── Fuzz ──────────────────────────────────────────────────

    function testFuzz_spotPrice_default_alwaysPositive(uint256 s) public view {
        // e^s > 0 for all s — price is always positive
        s = bound(s, 0, 130e18); // stay within exp() domain (< ~133)
        SD59x18 price = ExponentialLib.spotPrice(defaultParams, sd(int256(s)));
        assertTrue(price.unwrap() > 0);
    }

    function testFuzz_spotPrice_default_monotonicallyIncreasing(uint256 s1, uint256 s2) public view {
        // e^s is strictly increasing: s1 < s2 → p(s1) < p(s2)
        s1 = bound(s1, 0, 64e18);
        s2 = bound(s2, s1 + 1e18, 65e18); // guarantee s2 > s1
        SD59x18 p1 = ExponentialLib.spotPrice(defaultParams, sd(int256(s1)));
        SD59x18 p2 = ExponentialLib.spotPrice(defaultParams, sd(int256(s2)));
        assertTrue(p2 > p1);
    }

    function testFuzz_spotPrice_offset_exceedsDefaultByB(uint256 s) public view {
        // p_offset(s) - p_default(s) = 5 for all s
        s = bound(s, 0, 130e18);
        SD59x18 pOffset = ExponentialLib.spotPrice(offsetParams, sd(int256(s)));
        SD59x18 pDefault = ExponentialLib.spotPrice(defaultParams, sd(int256(s)));
        assertEq((pOffset - pDefault).unwrap(), 5e18);
    }

    function testFuzz_spotPrice_atZero_isExact(uint256 a, uint256 k, uint256 b) public view {
        // p(0) = a·e^0 + b = a + b (exact for any params)
        a = bound(a, 0.01e18, 100e18);
        k = bound(k, 0.01e18, 10e18);
        b = bound(b, 0, 100e18);

        bytes memory params = abi.encode(Types.ExponentialParams({
            a: int256(a),
            k: int256(k),
            b: int256(b)
        }));
        SD59x18 price = ExponentialLib.spotPrice(params, sd(0));
        assertEq(price.unwrap(), int256(a) + int256(b));
    }

    /*//////////////////////////////////////////////////////////////
            INTEGRATE: ∫(a·e^(k·s) + b)ds = a/k·e^(k·s) + b·s
    //////////////////////////////////////////////////////////////*/

    // ── Default: F(s) = e^s, ∫ = e^sTo - e^sFrom ─────────────

    function test_integrate_default_zeroToOne() public view {
        // ∫₀¹ e^s ds = e - 1 ≈ 1.71828...
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(0), sd(1e18));
        assertApproxEqRel(uint256(area.unwrap()), 1_718281828459045235, 0.0001e18);
    }

    function test_integrate_default_zeroToTwo() public view {
        // ∫₀² e^s ds = e² - 1 ≈ 6.38906...
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(0), sd(2e18));
        assertApproxEqRel(uint256(area.unwrap()), 6_389056098930650227, 0.0001e18);
    }

    function test_integrate_default_oneToTwo() public view {
        // ∫₁² e^s ds = e² - e ≈ 4.67077...
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(1e18), sd(2e18));
        assertApproxEqRel(uint256(area.unwrap()), 4_670774270471604992, 0.001e18);
    }

    function test_integrate_default_zeroToFive() public view {
        // ∫₀⁵ e^s ds = e⁵ - 1 ≈ 147.413...
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(0), sd(5e18));
        assertApproxEqRel(uint256(area.unwrap()), 147_413159102576603421, 0.001e18);
    }

    function test_integrate_default_zeroToTen() public view {
        // ∫₀¹⁰ e^s ds = e¹⁰ - 1 ≈ 22025.466...
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(0), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 22025_465794806716000000, 0.01e18);
    }

    // ── Offset: F(s) = e^s + 5s ──────────────────────────────

    function test_integrate_offset_zeroToOne() public view {
        // ∫₀¹ (e^s + 5) ds = (e - 1) + 5 ≈ 6.71828...
        SD59x18 area = ExponentialLib.integrate(offsetParams, sd(0), sd(1e18));
        assertApproxEqRel(uint256(area.unwrap()), 6_718281828459045235, 0.0001e18);
    }

    function test_integrate_offset_zeroToTwo() public view {
        // ∫₀² (e^s + 5) ds = (e² - 1) + 10 ≈ 16.38906...
        SD59x18 area = ExponentialLib.integrate(offsetParams, sd(0), sd(2e18));
        assertApproxEqRel(uint256(area.unwrap()), 16_389056098930650227, 0.0001e18);
    }

    function test_integrate_offset_oneToTwo() public view {
        // ∫₁² (e^s + 5) ds = (e² - e) + 5 ≈ 9.67077...
        SD59x18 area = ExponentialLib.integrate(offsetParams, sd(1e18), sd(2e18));
        assertApproxEqRel(uint256(area.unwrap()), 9_670774270471604992, 0.001e18);
    }

    // ── Slow growth: F(s) = 100·e^(0.01s) ────────────────────

    function test_integrate_slowGrowth_zeroToHundred() public view {
        // ∫₀¹⁰⁰ e^(0.01s) ds = (1/0.01)·(e^1 - 1) = 100·(e-1) ≈ 171.828...
        SD59x18 area = ExponentialLib.integrate(slowGrowthParams, sd(0), sd(100e18));
        assertApproxEqRel(uint256(area.unwrap()), 171_828182845904523500, 0.001e18);
    }

    function test_integrate_slowGrowth_zeroToTwoHundred() public view {
        // ∫₀²⁰⁰ e^(0.01s) ds = 100·(e^2 - 1) ≈ 638.906...
        SD59x18 area = ExponentialLib.integrate(slowGrowthParams, sd(0), sd(200e18));
        assertApproxEqRel(uint256(area.unwrap()), 638_905609893065022700, 0.001e18);
    }

    // ── Scaled: F(s) = 6·e^(0.5s) + 2s (a/k = 3/0.5 = 6) ───

    function test_integrate_scaled_zeroToTwo() public view {
        // ∫₀² (3·e^(0.5s) + 2) ds = 6·(e^1 - 1) + 4 ≈ 14.30969...
        SD59x18 area = ExponentialLib.integrate(scaledParams, sd(0), sd(2e18));
        assertApproxEqRel(uint256(area.unwrap()), 14_309690970754271410, 0.001e18);
    }

    function test_integrate_scaled_zeroToFour() public view {
        // ∫₀⁴ (3·e^(0.5s) + 2) ds = 6·(e^2 - 1) + 8 ≈ 46.33434...
        SD59x18 area = ExponentialLib.integrate(scaledParams, sd(0), sd(4e18));
        assertApproxEqRel(uint256(area.unwrap()), 46_334336593583901362, 0.001e18);
    }

    function test_integrate_scaled_twoToFour() public view {
        // ∫₂⁴ = ∫₀⁴ - ∫₀² = 46.334... - 14.310... ≈ 32.025...
        SD59x18 full = ExponentialLib.integrate(scaledParams, sd(0), sd(4e18));
        SD59x18 first = ExponentialLib.integrate(scaledParams, sd(0), sd(2e18));
        SD59x18 second = ExponentialLib.integrate(scaledParams, sd(2e18), sd(4e18));
        assertEq(full.unwrap(), (first + second).unwrap());
    }

    // ── Small amplitude: F(s) = 0.1·e^s ──────────────────────

    function test_integrate_smallAmp_zeroToOne() public view {
        // ∫₀¹ 0.1·e^s ds = 0.1·(e - 1) ≈ 0.17183...
        SD59x18 area = ExponentialLib.integrate(smallAmpParams, sd(0), sd(1e18));
        assertApproxEqRel(uint256(area.unwrap()), 171828182845904523, 0.001e18);
    }

    function test_integrate_smallAmp_zeroToFive() public view {
        // ∫₀⁵ 0.1·e^s ds = 0.1·(e⁵ - 1) ≈ 14.741...
        SD59x18 area = ExponentialLib.integrate(smallAmpParams, sd(0), sd(5e18));
        assertApproxEqRel(uint256(area.unwrap()), 14_741315910257660342, 0.001e18);
    }

    // ── Zero width ────────────────────────────────────────────

    function test_integrate_zeroWidth_returnsZero() public view {
        assertEq(ExponentialLib.integrate(defaultParams, sd(5e18), sd(5e18)).unwrap(), 0);
        assertEq(ExponentialLib.integrate(scaledParams, sd(3e18), sd(3e18)).unwrap(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀⁵ = ∫₀² + ∫₂⁵
        SD59x18 whole = ExponentialLib.integrate(defaultParams, sd(0), sd(5e18));
        SD59x18 part1 = ExponentialLib.integrate(defaultParams, sd(0), sd(2e18));
        SD59x18 part2 = ExponentialLib.integrate(defaultParams, sd(2e18), sd(5e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_offset() public view {
        // ∫₀⁴ = ∫₀¹ + ∫₁⁴
        SD59x18 whole = ExponentialLib.integrate(offsetParams, sd(0), sd(4e18));
        SD59x18 part1 = ExponentialLib.integrate(offsetParams, sd(0), sd(1e18));
        SD59x18 part2 = ExponentialLib.integrate(offsetParams, sd(1e18), sd(4e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_threeWaySplit() public view {
        // ∫₀⁶ = ∫₀² + ∫₂⁴ + ∫₄⁶
        SD59x18 whole = ExponentialLib.integrate(defaultParams, sd(0), sd(6e18));
        SD59x18 p1 = ExponentialLib.integrate(defaultParams, sd(0), sd(2e18));
        SD59x18 p2 = ExponentialLib.integrate(defaultParams, sd(2e18), sd(4e18));
        SD59x18 p3 = ExponentialLib.integrate(defaultParams, sd(4e18), sd(6e18));
        assertEq(whole.unwrap(), (p1 + p2 + p3).unwrap());
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For tiny δ, ∫[s, s+δ] ≈ p(s)·δ
        SD59x18 s = sd(3e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = ExponentialLib.spotPrice(defaultParams, s);
        SD59x18 area = ExponentialLib.integrate(defaultParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function test_spotIntegralConsistency_scaled() public view {
        SD59x18 s = sd(4e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = ExponentialLib.spotPrice(scaledParams, s);
        SD59x18 area = ExponentialLib.integrate(scaledParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ: UNIVERSAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzz_integrate_additivity(uint256 a, uint256 b, uint256 c) public view {
        // ∫[a,c] = ∫[a,b] + ∫[b,c]
        a = bound(a, 0, 30e18);
        b = bound(b, a, 60e18);
        c = bound(c, b, 90e18);

        SD59x18 whole = ExponentialLib.integrate(defaultParams, sd(int256(a)), sd(int256(c)));
        SD59x18 part1 = ExponentialLib.integrate(defaultParams, sd(int256(a)), sd(int256(b)));
        SD59x18 part2 = ExponentialLib.integrate(defaultParams, sd(int256(b)), sd(int256(c)));

        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function testFuzz_integrate_monotonicity(uint256 start, uint256 end1, uint256 end2) public view {
        // Wider range → larger area (e^s > 0 everywhere)
        start = bound(start, 0, 30e18);
        end1 = bound(end1, start, 60e18);
        end2 = bound(end2, end1, 90e18);

        SD59x18 area1 = ExponentialLib.integrate(defaultParams, sd(int256(start)), sd(int256(end1)));
        SD59x18 area2 = ExponentialLib.integrate(defaultParams, sd(int256(start)), sd(int256(end2)));

        assertTrue(area2 >= area1);
    }

    function testFuzz_integrate_nonNegative(uint256 from, uint256 to) public view {
        // e^s > 0, so integral is always non-negative for to >= from
        from = bound(from, 0, 60e18);
        to = bound(to, from, 120e18);

        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        assertTrue(area.unwrap() >= 0);
    }

    function testFuzz_integrate_zeroWidth_returnsZero(uint256 s) public view {
        s = bound(s, 0, 100e18);
        assertEq(ExponentialLib.integrate(defaultParams, sd(int256(s)), sd(int256(s))).unwrap(), 0);
    }

    function testFuzz_spotIntegralConsistency(uint256 s) public view {
        // Fundamental theorem: ∫[s, s+δ] ≈ p(s)·δ for tiny δ
        s = bound(s, 0, 50e18);
        SD59x18 delta = sd(0.0001e18);

        SD59x18 spot = ExponentialLib.spotPrice(defaultParams, sd(int256(s)));
        SD59x18 area = ExponentialLib.integrate(defaultParams, sd(int256(s)), sd(int256(s)) + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function testFuzz_integrate_offset_addsBsLinearTerm(uint256 from, uint256 to) public view {
        // ∫ (e^s + 5) ds - ∫ e^s ds = 5·(to - from)
        from = bound(from, 0, 60e18);
        to = bound(to, from + 1e18, 120e18);

        SD59x18 areaOffset = ExponentialLib.integrate(offsetParams, sd(int256(from)), sd(int256(to)));
        SD59x18 areaDefault = ExponentialLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        SD59x18 bTerm = sd(5e18) * (sd(int256(to)) - sd(int256(from)));

        assertEq(areaOffset.unwrap(), (areaDefault + bTerm).unwrap());
    }
}