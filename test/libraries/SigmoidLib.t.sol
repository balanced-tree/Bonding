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
        d = bound(d, 0, 35e18); // keep both exp() args in domain
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
}