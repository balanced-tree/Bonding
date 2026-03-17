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

    /*//////////////////////////////////////////////////////////////
            SPOT PRICE: p(s) = maxVal / (1 + e^(-k·(s - s0))) + b
    //////////////////////////////////////////////////////////////*/

    // ── Default: p(s) = 10 / (1 + e^(-(s-5))) ────────────────

    function test_spotPrice_default_atMidpoint() public view {
        // p(s0) = maxVal / (1 + e^0) + b = 10/2 = 5 (exact — e^0 = 1)
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(5e18));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_default_atZero() public view {
        // p(0) = 10 / (1 + e^5) ≈ 10 / 149.413 ≈ 0.06693...
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(0));
        assertApproxEqRel(uint256(price.unwrap()), 66928509242848554, 0.01e18);
    }

    function test_spotPrice_default_atTen() public view {
        // p(10) = 10 / (1 + e^(-5)) ≈ 9.93307...
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(10e18));
        assertApproxEqRel(uint256(price.unwrap()), 9_933071490757151446, 0.01e18);
    }

    function test_spotPrice_default_atThree() public view {
        // p(3) = 10 / (1 + e^2) ≈ 1.19203...
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(3e18));
        assertApproxEqRel(uint256(price.unwrap()), 1_192029220221175560, 0.01e18);
    }

    function test_spotPrice_default_atSeven() public view {
        // p(7) = 10 / (1 + e^(-2)) ≈ 8.80797...
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(7e18));
        assertApproxEqRel(uint256(price.unwrap()), 8_807970779778824440, 0.01e18);
    }

    function test_spotPrice_default_symmetry() public view {
        // Sigmoid symmetry: p(s0+d) + p(s0-d) = maxVal for b=0
        // p(3) + p(7) = 10, p(0) + p(10) = 10
        SD59x18 p3 = SigmoidLib.spotPrice(defaultParams, sd(3e18));
        SD59x18 p7 = SigmoidLib.spotPrice(defaultParams, sd(7e18));
        assertApproxEqRel(uint256((p3 + p7).unwrap()), 10e18, 0.001e18);

        SD59x18 p0 = SigmoidLib.spotPrice(defaultParams, sd(0));
        SD59x18 p10 = SigmoidLib.spotPrice(defaultParams, sd(10e18));
        assertApproxEqRel(uint256((p0 + p10).unwrap()), 10e18, 0.001e18);
    }

    // ── Offset: p(s) = 10 / (1 + e^(-(s-5))) + 3 ────────────

    function test_spotPrice_offset_atMidpoint() public view {
        // p(5) = maxVal/2 + b = 5 + 3 = 8 (exact)
        SD59x18 price = SigmoidLib.spotPrice(offsetParams, sd(5e18));
        assertEq(price.unwrap(), 8e18);
    }

    function test_spotPrice_offset_atZero() public view {
        // p(0) ≈ 0.06693 + 3 = 3.06693...
        SD59x18 price = SigmoidLib.spotPrice(offsetParams, sd(0));
        assertApproxEqRel(uint256(price.unwrap()), 3_066928509242848554, 0.01e18);
    }

    function test_spotPrice_offset_exceedsDefaultByB() public view {
        // p_offset(s) - p_default(s) = b = 3 for all s
        SD59x18 s = sd(7e18);
        SD59x18 pOffset = SigmoidLib.spotPrice(offsetParams, s);
        SD59x18 pDefault = SigmoidLib.spotPrice(defaultParams, s);
        assertEq((pOffset - pDefault).unwrap(), 3e18);
    }

    // ── Steep: p(s) = 10 / (1 + e^(-5·(s-5))) ───────────────

    function test_spotPrice_steep_atMidpoint() public view {
        // p(5) = 10/2 = 5 (exact, same midpoint value regardless of k)
        SD59x18 price = SigmoidLib.spotPrice(steepParams, sd(5e18));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_steep_atFour() public view {
        // p(4) = 10 / (1 + e^(-5·(-1))) = 10 / (1 + e^5) ≈ 0.06693...
        // Same as default at s=0 because the distance from midpoint × k is the same
        SD59x18 price = SigmoidLib.spotPrice(steepParams, sd(4e18));
        assertApproxEqRel(uint256(price.unwrap()), 66928509242848554, 0.01e18);
    }

    function test_spotPrice_steep_atSix() public view {
        // p(6) = 10 / (1 + e^(-5)) ≈ 9.93307...
        SD59x18 price = SigmoidLib.spotPrice(steepParams, sd(6e18));
        assertApproxEqRel(uint256(price.unwrap()), 9_933071490757151446, 0.01e18);
    }

    function test_spotPrice_steep_sharpTransition() public view {
        // Steep sigmoid: very close to 0 below midpoint, very close to maxVal above
        SD59x18 pBelow = SigmoidLib.spotPrice(steepParams, sd(3e18));
        SD59x18 pAbove = SigmoidLib.spotPrice(steepParams, sd(7e18));
        // p(3) should be very small (k·distance = 5·2 = 10 → e^10 denominator)
        assertTrue(pBelow.unwrap() < 0.01e18); // < 0.01
        // p(7) should be very close to 10
        assertTrue(pAbove.unwrap() > 9.99e18); // > 9.99
    }

    // ── Gentle: p(s) = 10 / (1 + e^(-0.1·(s-50))) ──────────

    function test_spotPrice_gentle_atMidpoint() public view {
        // p(50) = 10/2 = 5 (exact)
        SD59x18 price = SigmoidLib.spotPrice(gentleParams, sd(50e18));
        assertEq(price.unwrap(), 5e18);
    }

    function test_spotPrice_gentle_atZero() public view {
        // p(0) = 10 / (1 + e^(-0.1·(-50))) = 10 / (1 + e^5) ≈ 0.06693...
        SD59x18 price = SigmoidLib.spotPrice(gentleParams, sd(0));
        assertApproxEqRel(uint256(price.unwrap()), 66928509242848554, 0.01e18);
    }

    function test_spotPrice_gentle_atHundred() public view {
        // p(100) = 10 / (1 + e^(-0.1·50)) = 10 / (1 + e^(-5)) ≈ 9.93307...
        SD59x18 price = SigmoidLib.spotPrice(gentleParams, sd(100e18));
        assertApproxEqRel(uint256(price.unwrap()), 9_933071490757151446, 0.01e18);
    }

    function test_spotPrice_gentle_slowTransition() public view {
        // Gentle curve: at midpoint ± 10 the price is still far from the asymptotes
        // p(40) = 10 / (1 + e^1) ≈ 10 / 3.7183 ≈ 2.689...
        SD59x18 p40 = SigmoidLib.spotPrice(gentleParams, sd(40e18));
        assertTrue(p40.unwrap() > 2e18 && p40.unwrap() < 4e18);

        // p(60) = 10 / (1 + e^(-1)) ≈ 10 / 1.368 ≈ 7.311...
        SD59x18 p60 = SigmoidLib.spotPrice(gentleParams, sd(60e18));
        assertTrue(p60.unwrap() > 6e18 && p60.unwrap() < 8e18);
    }

    // ── Large maxVal: p(s) = 100 / (1 + e^(-(s-10))) ─────────

    function test_spotPrice_largeMaxVal_atMidpoint() public view {
        // p(10) = 100/2 = 50 (exact)
        SD59x18 price = SigmoidLib.spotPrice(largeMaxValParams, sd(10e18));
        assertEq(price.unwrap(), 50e18);
    }

    function test_spotPrice_largeMaxVal_atZero() public view {
        // p(0) = 100 / (1 + e^10) ≈ 100 / 22027.466 ≈ 0.00454...
        SD59x18 price = SigmoidLib.spotPrice(largeMaxValParams, sd(0));
        assertTrue(price.unwrap() > 0);
        assertTrue(price.unwrap() < 0.01e18);
    }

    function test_spotPrice_largeMaxVal_atTwenty() public view {
        // p(20) = 100 / (1 + e^(-10)) ≈ 99.995...
        SD59x18 price = SigmoidLib.spotPrice(largeMaxValParams, sd(20e18));
        assertApproxEqRel(uint256(price.unwrap()), 100e18, 0.01e18);
    }

    // ── Cross-param relational tests ──────────────────────────

    function test_spotPrice_steepVsDefault_steeperAtDistance() public view {
        // At 1 unit from midpoint, steep sigmoid is further from midpoint value than default
        // steep has larger |p - maxVal/2| at same distance from s0
        SD59x18 pDefaultAbove = SigmoidLib.spotPrice(defaultParams, sd(6e18)); // s0+1
        SD59x18 pSteepAbove = SigmoidLib.spotPrice(steepParams, sd(6e18)); // s0+1
        // steep should be closer to maxVal than default
        assertTrue(pSteepAbove > pDefaultAbove);
    }

    function test_spotPrice_allMidpointsEqual() public view {
        // All param sets with b=0 have p(s0) = maxVal/2
        assertEq(SigmoidLib.spotPrice(defaultParams, sd(5e18)).unwrap(), 5e18);
        assertEq(SigmoidLib.spotPrice(steepParams, sd(5e18)).unwrap(), 5e18);
        assertEq(SigmoidLib.spotPrice(gentleParams, sd(50e18)).unwrap(), 5e18);
        assertEq(SigmoidLib.spotPrice(largeMaxValParams, sd(10e18)).unwrap(), 50e18);
    }

    // ── Fuzz ──────────────────────────────────────────────────

    function testFuzz_spotPrice_default_boundedByMaxVal(uint256 s) public view {
        // 0 < p(s) < maxVal for all s (with b=0)
        s = bound(s, 0, 40e18); // keep -k·(s-s0) in exp() domain
        SD59x18 price = SigmoidLib.spotPrice(defaultParams, sd(int256(s)));
        assertTrue(price.unwrap() > 0);
        assertTrue(price.unwrap() < 10e18);
    }

    function testFuzz_spotPrice_default_monotonicallyIncreasing(uint256 s1, uint256 s2) public view {
        // Sigmoid is strictly increasing: s1 < s2 → p(s1) < p(s2)
        s1 = bound(s1, 0, 19e18);
        s2 = bound(s2, s1 + 1e18, 20e18);
        SD59x18 p1 = SigmoidLib.spotPrice(defaultParams, sd(int256(s1)));
        SD59x18 p2 = SigmoidLib.spotPrice(defaultParams, sd(int256(s2)));
        assertTrue(p2 > p1);
    }

    function testFuzz_spotPrice_default_symmetry(uint256 d) public view {
        // p(s0 + d) + p(s0 - d) ≈ maxVal (for b=0)
        // d ≤ 5e18 so s0-d stays non-negative; also keeps exp() in domain
        d = bound(d, 0, 5e18);
        SD59x18 pPlus = SigmoidLib.spotPrice(defaultParams, sd(int256(5e18 + d)));
        SD59x18 pMinus = SigmoidLib.spotPrice(defaultParams, sd(int256(5e18 - d)));
        assertApproxEqRel(uint256((pPlus + pMinus).unwrap()), 10e18, 0.001e18);
    }

    function testFuzz_spotPrice_offset_exceedsDefaultByB(uint256 s) public view {
        // p_offset(s) - p_default(s) = b = 3 for all s
        s = bound(s, 0, 40e18);
        SD59x18 pOffset = SigmoidLib.spotPrice(offsetParams, sd(int256(s)));
        SD59x18 pDefault = SigmoidLib.spotPrice(defaultParams, sd(int256(s)));
        assertEq((pOffset - pDefault).unwrap(), 3e18);
    }

    function testFuzz_spotPrice_atMidpoint_isExact(uint256 maxVal, uint256 k, uint256 s0, uint256 b) public view {
        // p(s0) = maxVal/2 + b for any params (exact — exp(0) = 1)
        maxVal = bound(maxVal, 1e18, 1000e18);
        k = bound(k, 0.01e18, 10e18);
        s0 = bound(s0, 0, 100e18);
        b = bound(b, 0, 100e18);

        bytes memory params = abi.encode(Types.SigmoidParams({
            maxVal: int256(maxVal),
            k: int256(k),
            s0: int256(s0),
            b: int256(b)
        }));
        SD59x18 price = SigmoidLib.spotPrice(params, sd(int256(s0)));
        assertEq(price.unwrap(), int256(maxVal) / 2 + int256(b));
    }

    /*//////////////////////////////////////////////////////////////
        INTEGRATE: ∫p(s)ds = maxVal/k · ln(1 + e^(k·(s-s0))) + b·s
    //////////////////////////////////////////////////////////////*/

    // ── Symmetric interval identity ───────────────────────────
    // For b=0: ∫[s0-d, s0+d] = maxVal · d  (sigmoid symmetry: σ(x)+σ(-x) = 1)
    // For b>0: ∫[s0-d, s0+d] = maxVal · d + b · 2d

    function test_integrate_default_symmetric_zeroToTen() public view {
        // ∫₀¹⁰ = ∫[5-5, 5+5] = 10 · 5 = 50
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(0), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 50e18, 0.001e18);
    }

    function test_integrate_default_symmetric_threeToSeven() public view {
        // ∫₃⁷ = ∫[5-2, 5+2] = 10 · 2 = 20
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(3e18), sd(7e18));
        assertApproxEqRel(uint256(area.unwrap()), 20e18, 0.001e18);
    }

    function test_integrate_default_symmetric_fourToSix() public view {
        // ∫₄⁶ = ∫[5-1, 5+1] = 10 · 1 = 10
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(4e18), sd(6e18));
        assertApproxEqRel(uint256(area.unwrap()), 10e18, 0.001e18);
    }

    function test_integrate_offset_symmetric_zeroToTen() public view {
        // ∫₀¹⁰ = maxVal · d + b · 2d = 10 · 5 + 3 · 10 = 80
        SD59x18 area = SigmoidLib.integrate(offsetParams, sd(0), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 80e18, 0.001e18);
    }

    function test_integrate_offset_symmetric_threeToSeven() public view {
        // ∫₃⁷ = 10 · 2 + 3 · 4 = 32
        SD59x18 area = SigmoidLib.integrate(offsetParams, sd(3e18), sd(7e18));
        assertApproxEqRel(uint256(area.unwrap()), 32e18, 0.001e18);
    }

    // ── Non-symmetric intervals ───────────────────────────────

    function test_integrate_default_zeroToFive() public view {
        // ∫₀⁵ = F(5) - F(0) = 10·ln(2) - 10·ln(1+e^(-5)) ≈ 6.9315 - 0.0672 ≈ 6.8643
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(0), sd(5e18));
        assertApproxEqRel(uint256(area.unwrap()), 6_864299580424148980, 0.01e18);
    }

    function test_integrate_default_fiveToTen() public view {
        // ∫₅¹⁰ = ∫₀¹⁰ - ∫₀⁵ ≈ 50 - 6.8643 ≈ 43.1357
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(5e18), sd(10e18));
        assertApproxEqRel(uint256(area.unwrap()), 43_135700419575851020, 0.01e18);
    }

    function test_integrate_default_belowMidpoint_smallArea() public view {
        // Far below midpoint, price is small so integral is small
        // p(0) ≈ 0.067, p(1) ≈ 0.180, so ∫₀¹ ≈ 0.12
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(0), sd(1e18));
        assertTrue(area.unwrap() > 0);
        assertTrue(area.unwrap() < 0.5e18);
    }

    // ── Steep: sharp transition ───────────────────────────────

    function test_integrate_steep_symmetric_fourToSix() public view {
        // ∫₄⁶ = ∫[5-1, 5+1] = 10 · 1 = 10 (same identity, any k)
        SD59x18 area = SigmoidLib.integrate(steepParams, sd(4e18), sd(6e18));
        assertApproxEqRel(uint256(area.unwrap()), 10e18, 0.001e18);
    }

    // ── Gentle: wide spread ───────────────────────────────────

    function test_integrate_gentle_symmetric_zeroToHundred() public view {
        // ∫₀¹⁰⁰ = ∫[50-50, 50+50] = 10 · 50 = 500
        SD59x18 area = SigmoidLib.integrate(gentleParams, sd(0), sd(100e18));
        assertApproxEqRel(uint256(area.unwrap()), 500e18, 0.001e18);
    }

    function test_integrate_gentle_symmetric_fortyToSixty() public view {
        // ∫₄₀⁶⁰ = ∫[50-10, 50+10] = 10 · 10 = 100
        SD59x18 area = SigmoidLib.integrate(gentleParams, sd(40e18), sd(60e18));
        assertApproxEqRel(uint256(area.unwrap()), 100e18, 0.001e18);
    }

    // ── Large maxVal ──────────────────────────────────────────

    function test_integrate_largeMaxVal_symmetric_fiveToFifteen() public view {
        // ∫₅¹⁵ = ∫[10-5, 10+5] = 100 · 5 = 500
        SD59x18 area = SigmoidLib.integrate(largeMaxValParams, sd(5e18), sd(15e18));
        assertApproxEqRel(uint256(area.unwrap()), 500e18, 0.001e18);
    }

    // ── Zero width ────────────────────────────────────────────

    function test_integrate_zeroWidth_returnsZero() public view {
        assertEq(SigmoidLib.integrate(defaultParams, sd(5e18), sd(5e18)).unwrap(), 0);
        assertEq(SigmoidLib.integrate(steepParams, sd(5e18), sd(5e18)).unwrap(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            ADDITIVITY
    //////////////////////////////////////////////////////////////*/

    function test_integrate_additivity_default() public view {
        // ∫₀¹⁰ = ∫₀⁵ + ∫₅¹⁰
        SD59x18 whole = SigmoidLib.integrate(defaultParams, sd(0), sd(10e18));
        SD59x18 part1 = SigmoidLib.integrate(defaultParams, sd(0), sd(5e18));
        SD59x18 part2 = SigmoidLib.integrate(defaultParams, sd(5e18), sd(10e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_offset() public view {
        // ∫₀¹⁰ = ∫₀³ + ∫₃¹⁰
        SD59x18 whole = SigmoidLib.integrate(offsetParams, sd(0), sd(10e18));
        SD59x18 part1 = SigmoidLib.integrate(offsetParams, sd(0), sd(3e18));
        SD59x18 part2 = SigmoidLib.integrate(offsetParams, sd(3e18), sd(10e18));
        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function test_integrate_additivity_threeWaySplit() public view {
        // ∫₀⁹ = ∫₀³ + ∫₃⁶ + ∫₆⁹
        SD59x18 whole = SigmoidLib.integrate(defaultParams, sd(0), sd(9e18));
        SD59x18 p1 = SigmoidLib.integrate(defaultParams, sd(0), sd(3e18));
        SD59x18 p2 = SigmoidLib.integrate(defaultParams, sd(3e18), sd(6e18));
        SD59x18 p3 = SigmoidLib.integrate(defaultParams, sd(6e18), sd(9e18));
        assertEq(whole.unwrap(), (p1 + p2 + p3).unwrap());
    }

    /*//////////////////////////////////////////////////////////////
                      SPOT-INTEGRAL CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_spotIntegralConsistency_default() public view {
        // For tiny δ, ∫[s, s+δ] ≈ p(s)·δ
        SD59x18 s = sd(5e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = SigmoidLib.spotPrice(defaultParams, s);
        SD59x18 area = SigmoidLib.integrate(defaultParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    function test_spotIntegralConsistency_offset() public view {
        SD59x18 s = sd(7e18);
        SD59x18 delta = sd(0.001e18);

        SD59x18 spot = SigmoidLib.spotPrice(offsetParams, s);
        SD59x18 area = SigmoidLib.integrate(offsetParams, s, s + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ: UNIVERSAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzz_integrate_additivity(uint256 a, uint256 b, uint256 c) public view {
        // ∫[a,c] = ∫[a,b] + ∫[b,c]
        a = bound(a, 0, 10e18);
        b = bound(b, a, 20e18);
        c = bound(c, b, 30e18);

        SD59x18 whole = SigmoidLib.integrate(defaultParams, sd(int256(a)), sd(int256(c)));
        SD59x18 part1 = SigmoidLib.integrate(defaultParams, sd(int256(a)), sd(int256(b)));
        SD59x18 part2 = SigmoidLib.integrate(defaultParams, sd(int256(b)), sd(int256(c)));

        assertEq(whole.unwrap(), (part1 + part2).unwrap());
    }

    function testFuzz_integrate_monotonicity(uint256 start, uint256 end1, uint256 end2) public view {
        // Wider range → larger area (sigmoid is always positive for b=0, maxVal>0)
        start = bound(start, 0, 10e18);
        end1 = bound(end1, start, 20e18);
        end2 = bound(end2, end1, 30e18);

        SD59x18 area1 = SigmoidLib.integrate(defaultParams, sd(int256(start)), sd(int256(end1)));
        SD59x18 area2 = SigmoidLib.integrate(defaultParams, sd(int256(start)), sd(int256(end2)));

        assertTrue(area2 >= area1);
    }

    function testFuzz_integrate_nonNegative(uint256 from, uint256 to) public view {
        // Sigmoid with maxVal>0, b≥0 is always positive, so integral ≥ 0
        from = bound(from, 0, 20e18);
        to = bound(to, from + 1e18, 30e18);

        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        assertTrue(area.unwrap() >= 0);
    }

    function testFuzz_integrate_zeroWidth_returnsZero(uint256 s) public view {
        s = bound(s, 0, 30e18);
        assertEq(SigmoidLib.integrate(defaultParams, sd(int256(s)), sd(int256(s))).unwrap(), 0);
    }

    function testFuzz_integrate_symmetric_equalsMaxValTimesD(uint256 d) public view {
        // The key sigmoid identity: ∫[s0-d, s0+d] = maxVal · d (for b=0)
        d = bound(d, 1e18, 5e18); // keep within s0 and exp() domain
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(int256(5e18 - d)), sd(int256(5e18 + d)));
        int256 expected = 10e18 * int256(d) / 1e18; // maxVal · d
        assertApproxEqRel(uint256(area.unwrap()), uint256(expected), 0.001e18);
    }

    function testFuzz_integrate_offset_addsBsLinearTerm(uint256 from, uint256 to) public view {
        // ∫ (sigmoid + b) ds - ∫ sigmoid ds = b · (to - from)
        from = bound(from, 0, 15e18);
        to = bound(to, from + 1e18, 30e18);

        SD59x18 areaOffset = SigmoidLib.integrate(offsetParams, sd(int256(from)), sd(int256(to)));
        SD59x18 areaDefault = SigmoidLib.integrate(defaultParams, sd(int256(from)), sd(int256(to)));
        SD59x18 bTerm = sd(3e18) * (sd(int256(to)) - sd(int256(from)));

        assertEq(areaOffset.unwrap(), (areaDefault + bTerm).unwrap());
    }

    function testFuzz_spotIntegralConsistency(uint256 s) public view {
        // Fundamental theorem: ∫[s, s+δ] ≈ p(s)·δ for tiny δ
        s = bound(s, 0, 30e18);
        SD59x18 delta = sd(0.0001e18);

        SD59x18 spot = SigmoidLib.spotPrice(defaultParams, sd(int256(s)));
        SD59x18 area = SigmoidLib.integrate(defaultParams, sd(int256(s)), sd(int256(s)) + delta);
        SD59x18 approx = spot * delta;

        assertApproxEqRel(uint256(area.unwrap()), uint256(approx.unwrap()), 0.001e18);
    }
}