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

    /*//////////////////////////////////////////////////////////////
            INTEGRATE: ∫(a·s² + b·s + c)ds = a·s³/3 + b·s²/2 + c·s
    //////////////////////////////////////////////////////////////*/

    // ── Default: F(s) = s³/3 ──────────────────────────────────

    function test_integrate_default_zeroToTen() public view {
        // ∫₀¹⁰ s² ds = 10³/3 = 1000/3 ≈ 333.333...
        SD59x18 area = ParabolicLib.integrate(defaultParams, sd(0), sd(10e18));
        // Division by 3 truncates — allow 1 wei tolerance
        assertApproxEqAbs(uint256(area.unwrap()), 333_333333333333333333, 1);
    }

    function test_integrate_default_zeroToHundred() public view {
        // ∫₀¹⁰⁰ s² ds = 100³/3 = 1000000/3 ≈ 333333.333...
        SD59x18 area = ParabolicLib.integrate(defaultParams, sd(0), sd(100e18));
        assertApproxEqAbs(uint256(area.unwrap()), 333_333_333333333333333333, 1);
    }

    function test_integrate_default_nonZeroStart() public view {
        // ∫₁₀²⁰ s² ds = F(20) - F(10) = 8000/3 - 1000/3 = 7000/3 ≈ 2333.333...
        SD59x18 area = ParabolicLib.integrate(defaultParams, sd(10e18), sd(20e18));
        assertApproxEqAbs(uint256(area.unwrap()), 2_333_333333333333333333, 1);
    }

    function test_integrate_default_zeroToOne() public view {
        // ∫₀¹ s² ds = 1/3 ≈ 0.333...
        SD59x18 area = ParabolicLib.integrate(defaultParams, sd(0), sd(1e18));
        assertApproxEqAbs(uint256(area.unwrap()), 333333333333333333, 1);
    }

    // ── Full quadratic: F(s) = 2s³/3 + 3s²/2 + 5s ───────────

    function test_integrate_full_zeroToTen() public view {
        // F(10) = 2·1000/3 + 3·100/2 + 5·10 = 666.666... + 150 + 50 = 866.666...
        SD59x18 area = ParabolicLib.integrate(fullParams, sd(0), sd(10e18));
        assertApproxEqAbs(uint256(area.unwrap()), 866_666666666666666666, 1);
    }

    function test_integrate_full_fiveToTen() public view {
        // F(10) - F(5) = 866.666... - (2·125/3 + 3·25/2 + 25) = 866.666... - (83.333... + 37.5 + 25)
        // = 866.666... - 145.833... = 720.833...
        SD59x18 area = ParabolicLib.integrate(fullParams, sd(5e18), sd(10e18));
        assertApproxEqAbs(uint256(area.unwrap()), 720_833333333333333333, 1);
    }

    function test_integrate_full_zeroToOne() public view {
        // F(1) = 2/3 + 3/2 + 5 = 0.666... + 1.5 + 5 = 7.166...
        SD59x18 area = ParabolicLib.integrate(fullParams, sd(0), sd(1e18));
        assertApproxEqAbs(uint256(area.unwrap()), 7_166666666666666666, 1);
    }

    // ── Linear degenerate: F(s) = 2s² + s (exact, no /3 term) ─

    function test_integrate_linearDegenerate_zeroToTen() public view {
        // ∫₀¹⁰ (4s + 1) ds = [2s² + s]₀¹⁰ = 200 + 10 = 210
        SD59x18 area = ParabolicLib.integrate(linearDegenerateParams, sd(0), sd(10e18));
        assertEq(area.unwrap(), 210e18);
    }

    function test_integrate_linearDegenerate_tenToTwenty() public view {
        // F(20) - F(10) = (800 + 20) - (200 + 10) = 820 - 210 = 610
        SD59x18 area = ParabolicLib.integrate(linearDegenerateParams, sd(10e18), sd(20e18));
        assertEq(area.unwrap(), 610e18);
    }

    function test_integrate_linearDegenerate_zeroToFifty() public view {
        // F(50) = 2·2500 + 50 = 5050
        SD59x18 area = ParabolicLib.integrate(linearDegenerateParams, sd(0), sd(50e18));
        assertEq(area.unwrap(), 5050e18);
    }

    // ── Constant: F(s) = 7s (exact) ──────────────────────────

    function test_integrate_constant_zeroToHundred() public view {
        // ∫₀¹⁰⁰ 7 ds = 700
        SD59x18 area = ParabolicLib.integrate(constantParams, sd(0), sd(100e18));
        assertEq(area.unwrap(), 700e18);
    }

    function test_integrate_constant_tenToFifty() public view {
        // ∫₁₀⁵⁰ 7 ds = 7 · 40 = 280
        SD59x18 area = ParabolicLib.integrate(constantParams, sd(10e18), sd(50e18));
        assertEq(area.unwrap(), 280e18);
    }

    // ── Small coefficient: F(s) = 0.001·s³/3 + s ─────────────

    function test_integrate_smallCoeff_zeroToHundred() public view {
        // F(100) = 0.001·1000000/3 + 100 = 333.333... + 100 = 433.333...
        SD59x18 area = ParabolicLib.integrate(smallCoeffParams, sd(0), sd(100e18));
        assertApproxEqAbs(uint256(area.unwrap()), 433_333333333333333333, 1);
    }

    function test_integrate_smallCoeff_zeroToThousand() public view {
        // F(1000) = 0.001·1e9/3 + 1000 = 333333.333... + 1000 = 334333.333...
        SD59x18 area = ParabolicLib.integrate(smallCoeffParams, sd(0), sd(1000e18));
        assertApproxEqAbs(uint256(area.unwrap()), 334_333_333333333333333333, 1);
    }

    // ── Zero width ────────────────────────────────────────────

    function test_integrate_zeroWidth_returnsZero() public view {
        // ∫₁₀¹⁰ anything ds = 0
        assertEq(ParabolicLib.integrate(defaultParams, sd(10e18), sd(10e18)).unwrap(), 0);
        assertEq(ParabolicLib.integrate(fullParams, sd(50e18), sd(50e18)).unwrap(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀³⁰ = ∫₀¹⁰ + ∫₁₀³⁰
        SD59x18 whole = ParabolicLib.integrate(defaultParams, sd(0), sd(30e18));
        SD59x18 part1 = ParabolicLib.integrate(defaultParams, sd(0), sd(10e18));
        SD59x18 part2 = ParabolicLib.integrate(defaultParams, sd(10e18), sd(30e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_full() public view {
        // ∫₀²⁰ = ∫₀⁷ + ∫₇²⁰
        SD59x18 whole = ParabolicLib.integrate(fullParams, sd(0), sd(20e18));
        SD59x18 part1 = ParabolicLib.integrate(fullParams, sd(0), sd(7e18));
        SD59x18 part2 = ParabolicLib.integrate(fullParams, sd(7e18), sd(20e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_threeWaySplit() public view {
        // ∫₀³⁰ = ∫₀¹⁰ + ∫₁₀²⁰ + ∫₂₀³⁰
        SD59x18 whole = ParabolicLib.integrate(fullParams, sd(0), sd(30e18));
        SD59x18 p1 = ParabolicLib.integrate(fullParams, sd(0), sd(10e18));
        SD59x18 p2 = ParabolicLib.integrate(fullParams, sd(10e18), sd(20e18));
        SD59x18 p3 = ParabolicLib.integrate(fullParams, sd(20e18), sd(30e18));
        assertEq(whole.unwrap(), (p1 + p2 + p3).unwrap());
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For a tiny δ, integrate(s, s+δ) ≈ spotPrice(s) · δ
        SD59x18 s = sd(50e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = ParabolicLib.spotPrice(defaultParams, s);
        SD59x18 area = ParabolicLib.integrate(defaultParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function test_spotIntegralConsistency_full() public view {
        SD59x18 s = sd(25e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = ParabolicLib.spotPrice(fullParams, s);
        SD59x18 area = ParabolicLib.integrate(fullParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ: UNIVERSAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzz_integrate_additivity(uint256 a, uint256 b, uint256 c) public view {
        a = bound(a, 0, 300e18);
        b = bound(b, a, 600e18);
        c = bound(c, b, 900e18);

        SD59x18 whole = ParabolicLib.integrate(defaultParams, sd(int256(a)), sd(int256(c)));
        SD59x18 part1 = ParabolicLib.integrate(defaultParams, sd(int256(a)), sd(int256(b)));
        SD59x18 part2 = ParabolicLib.integrate(defaultParams, sd(int256(b)), sd(int256(c)));

        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function testFuzz_integrate_monotonicity(uint256 start, uint256 end1, uint256 end2) public view {
        // Wider range → larger area (for non-negative prices)
        start = bound(start, 0, 300e18);
        end1 = bound(end1, start, 600e18);
        end2 = bound(end2, end1, 900e18);

        SD59x18 area1 = ParabolicLib.integrate(defaultParams, sd(int256(start)), sd(int256(end1)));
        SD59x18 area2 = ParabolicLib.integrate(defaultParams, sd(int256(start)), sd(int256(end2)));

        assertTrue(area2 >= area1);
    }

    function testFuzz_integrate_constant_isExact(uint256 from, uint256 to) public view {
        // For constant price p(s) = 7, integral is exactly 7·(to - from)
        from = bound(from, 0, 500e18);
        to = bound(to, from, 1000e18);

        SD59x18 area = ParabolicLib.integrate(constantParams, sd(int256(from)), sd(int256(to)));
        int256 expected = 7e18 * (int256(to) - int256(from)) / 1e18;

        assertEq(area.unwrap(), expected);
    }

    function testFuzz_integrate_linearDegenerate_isExact(uint256 from, uint256 to) public view {
        // For p(s) = 4s + 1, integral = 2s² + s — no /3 term, so exact
        from = bound(from, 0, 500e18);
        to = bound(to, from, 1000e18);

        SD59x18 area = ParabolicLib.integrate(linearDegenerateParams, sd(int256(from)), sd(int256(to)));

        // F(s) = 2s² + s → F(to) - F(from)
        int256 fTo = 2 * int256(to) * int256(to) / 1e18 + int256(to);
        int256 fFrom = 2 * int256(from) * int256(from) / 1e18 + int256(from);

        assertEq(area.unwrap(), fTo - fFrom);
    }

    function testFuzz_spotPrice_full_matchesFormula(uint256 s) public view {
        // p(s) = 2s² + 3s + 5 — verify against manual SD59x18 computation
        // SD59x18 chained mul (a*s*s) rounds differently from manual (s*s/1e18)*2 at large s
        s = bound(s, 0, 1000e18);
        SD59x18 price = ParabolicLib.spotPrice(fullParams, sd(int256(s)));
        int256 s2 = int256(s) * int256(s) / 1e18;
        int256 expected = 2 * s2 + 3 * int256(s) + 5e18;
        assertApproxEqAbs(price.unwrap(), expected, 2);
    }

    function testFuzz_spotPrice_smallCoeff_matchesFormula(uint256 s) public view {
        // p(s) = 0.001·s² + 1
        // Small coefficient amplifies rounding divergence between chained SD59x18 mul
        // and manual int math — use relative tolerance instead of absolute
        s = bound(s, 1e18, 1000e18);
        SD59x18 price = ParabolicLib.spotPrice(smallCoeffParams, sd(int256(s)));
        int256 s2 = int256(s) * int256(s) / 1e18;
        int256 expected = int256(0.001e18) * s2 / 1e18 + 1e18;
        assertApproxEqRel(uint256(price.unwrap()), uint256(expected), 0.0001e18);
    }

    function testFuzz_spotPrice_monotonicity(uint256 s1, uint256 s2) public view {
        // p(s) = s² is non-decreasing for s ≥ 0 → s1 ≤ s2 implies p(s1) ≤ p(s2)
        s1 = bound(s1, 0, 500e18);
        s2 = bound(s2, s1, 1000e18);

        SD59x18 p1 = ParabolicLib.spotPrice(defaultParams, sd(int256(s1)));
        SD59x18 p2 = ParabolicLib.spotPrice(defaultParams, sd(int256(s2)));

        assertTrue(p2 >= p1);
    }

    function testFuzz_integrate_nonNegative(uint256 from, uint256 to) public view {
        // For non-negative price curve p(s) = s², ∫[from, to] ≥ 0 when to ≥ from
        from = bound(from, 0, 500e18);
        to = bound(to, from, 1000e18);

        SD59x18 area = ParabolicLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        assertTrue(area.unwrap() >= 0);
    }

    function testFuzz_integrate_zeroWidth_returnsZero(uint256 s) public view {
        // ∫[s, s] = 0 for any supply point
        s = bound(s, 0, 1000e18);
        assertEq(ParabolicLib.integrate(defaultParams, sd(int256(s)), sd(int256(s))).unwrap(), 0);
        assertEq(ParabolicLib.integrate(fullParams, sd(int256(s)), sd(int256(s))).unwrap(), 0);
    }

    function testFuzz_spotIntegralConsistency(uint256 s) public view {
        // Fundamental theorem: for tiny δ, ∫[s, s+δ] ≈ p(s)·δ
        s = bound(s, 1e18, 999e18);
        SD59x18 delta = sd(0.0001e18);

        SD59x18 spot = ParabolicLib.spotPrice(fullParams, sd(int256(s)));
        SD59x18 area = ParabolicLib.integrate(fullParams, sd(int256(s)), sd(int256(s)) + delta);
        SD59x18 approx = spot * delta;

        // 0.1% tolerance — the quadratic curvature over tiny δ is negligible
        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function testFuzz_integrate_additivity_full(uint256 a, uint256 b, uint256 c) public view {
        // Additivity with full quadratic params: ∫[a,c] = ∫[a,b] + ∫[b,c]
        a = bound(a, 0, 300e18);
        b = bound(b, a, 600e18);
        c = bound(c, b, 900e18);

        SD59x18 whole = ParabolicLib.integrate(fullParams, sd(int256(a)), sd(int256(c)));
        SD59x18 part1 = ParabolicLib.integrate(fullParams, sd(int256(a)), sd(int256(b)));
        SD59x18 part2 = ParabolicLib.integrate(fullParams, sd(int256(b)), sd(int256(c)));

        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }
}