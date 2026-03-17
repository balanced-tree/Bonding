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
import { PriceLib } from "../../src/libraries/PriceLib.sol";

contract PriceLibTest is BaseTest, Helpers {
    // ── External wrappers for revert testing ──────────────────
    // PriceLib functions are `internal`, so vm.expectRevert needs an external call boundary.

    function exposed_getSpotPrice(Types.PiecewiseSegment[] memory segments, uint256 supply) external pure returns (uint256) {
        return PriceLib.getSpotPrice(segments, supply);
    }

    /*//////////////////////////////////////////////////////////////
                        SINGLE-SEGMENT ARRAYS
    //////////////////////////////////////////////////////////////*/

    // LINEAR p(s) = s over [0, 1000e18]
    // Simplest case — exact integral s²/2, ideal for verifying binary search accuracy
    Types.PiecewiseSegment[] internal linearSegments;

    // PARABOLIC p(s) = s² over [0, 1000e18]
    // Steeper growth than linear — tests binary search convergence on non-linear curves
    Types.PiecewiseSegment[] internal parabolicSegments;

    /*//////////////////////////////////////////////////////////////
                        MULTI-SEGMENT ARRAYS
    //////////////////////////////////////////////////////////////*/

    // Two segments: LINEAR [0, 500e18] → PARABOLIC [500e18, 1000e18]
    // Tests cross-segment integration and segment routing at the boundary
    Types.PiecewiseSegment[] internal linearParabolicSegments;

    // Two segments: LINEAR [0, 500e18] → LN [500e18, 1000e18]
    // Tests boundary between polynomial and transcendental formulas
    Types.PiecewiseSegment[] internal linearLnSegments;

    // Three segments: LINEAR [0, 200e18] → PARABOLIC [200e18, 600e18] → EXPONENTIAL [600e18, 700e18]
    // Tests integration spanning 3 segments and _findSegment for all positions
    Types.PiecewiseSegment[] internal threeSegments;

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS FOR TESTS
    //////////////////////////////////////////////////////////////*/

    // Boundary between segments in two-segment arrays
    uint256 internal constant BOUNDARY = 500e18;

    // Max supply across single-segment arrays
    uint256 internal constant MAX_SUPPLY = 1000e18;

    function setUp() public override {
        super.setUp();

        // ── Single segments ──────────────────────────────────────
        linearSegments.push(_createLinearSegment(0, MAX_SUPPLY));

        parabolicSegments.push(_createParabolicSegment(0, MAX_SUPPLY));

        // ── Two-segment: LINEAR → PARABOLIC ─────────────────────
        linearParabolicSegments.push(_createLinearSegment(0, BOUNDARY));
        linearParabolicSegments.push(_createParabolicSegment(BOUNDARY, MAX_SUPPLY));

        // ── Two-segment: LINEAR → LN ────────────────────────────
        linearLnSegments.push(_createLinearSegment(0, BOUNDARY));
        linearLnSegments.push(_createLnSegment(BOUNDARY, MAX_SUPPLY));

        // ── Three-segment: LINEAR → PARABOLIC → EXPONENTIAL ─────
        // Note: exponential uses k=0.01 to keep exp(k·s) within PRBMath domain at s=700
        threeSegments.push(_createLinearSegment(0, 200e18));
        threeSegments.push(_createParabolicSegment(200e18, 600e18));
        threeSegments.push(_createExponentialSegment(600e18, 700e18, 1e18, 0.01e18, 0));
    }

    /*//////////////////////////////////////////////////////////////
                    SPOT PRICE: SINGLE-SEGMENT ROUTING
    //////////////////////////////////////////////////////////////*/

    // ── LINEAR p(s) = s ───────────────────────────────────────

    function test_getSpotPrice_linear_atZero() public view {
        // p(0) = 0
        uint256 price = PriceLib.getSpotPrice(linearSegments, 0);
        assertEq(price, 0);
    }

    function test_getSpotPrice_linear_atOne() public view {
        // p(1) = 1
        uint256 price = PriceLib.getSpotPrice(linearSegments, 1e18);
        assertEq(price, 1e18);
    }

    function test_getSpotPrice_linear_atFifty() public view {
        // p(50) = 50
        uint256 price = PriceLib.getSpotPrice(linearSegments, 50e18);
        assertEq(price, 50e18);
    }

    function test_getSpotPrice_linear_atFiveHundred() public view {
        // p(500) = 500
        uint256 price = PriceLib.getSpotPrice(linearSegments, 500e18);
        assertEq(price, 500e18);
    }

    // ── PARABOLIC p(s) = s² ──────────────────────────────────

    function test_getSpotPrice_parabolic_atZero() public view {
        // p(0) = 0
        uint256 price = PriceLib.getSpotPrice(parabolicSegments, 0);
        assertEq(price, 0);
    }

    function test_getSpotPrice_parabolic_atOne() public view {
        // p(1) = 1
        uint256 price = PriceLib.getSpotPrice(parabolicSegments, 1e18);
        assertEq(price, 1e18);
    }

    function test_getSpotPrice_parabolic_atTen() public view {
        // p(10) = 100
        uint256 price = PriceLib.getSpotPrice(parabolicSegments, 10e18);
        assertEq(price, 100e18);
    }

    function test_getSpotPrice_parabolic_atHundred() public view {
        // p(100) = 10000
        uint256 price = PriceLib.getSpotPrice(parabolicSegments, 100e18);
        assertEq(price, 10_000e18);
    }

    // ── Relational: parabolic grows faster than linear ────────

    function test_getSpotPrice_parabolicGrowsFasterThanLinear() public view {
        // For s > 1: s² > s
        uint256 supply = 50e18;
        uint256 linearPrice = PriceLib.getSpotPrice(linearSegments, supply);
        uint256 parabolicPrice = PriceLib.getSpotPrice(parabolicSegments, supply);
        assertTrue(parabolicPrice > linearPrice);
    }

    // ── Reverts ───────────────────────────────────────────────

    function test_getSpotPrice_reverts_supplyOutOfRange() public {
        // supply = 1000e18 is AT the supplyEnd, which is exclusive → out of range
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(linearSegments, MAX_SUPPLY);
    }

    function test_getSpotPrice_reverts_supplyBeyondEnd() public {
        // supply well past the last segment
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(linearSegments, MAX_SUPPLY + 1e18);
    }

    // ── Fuzz: single-segment ─────────────────────────────────

    function testFuzz_getSpotPrice_linear_equalsSupply(uint256 s) public view {
        // p(s) = s for default linear params
        s = bound(s, 0, MAX_SUPPLY - 1);
        uint256 price = PriceLib.getSpotPrice(linearSegments, s);
        assertEq(price, s);
    }

    function testFuzz_getSpotPrice_parabolic_equalsSquare(uint256 s) public view {
        // p(s) = s² for default parabolic params
        s = bound(s, 0, MAX_SUPPLY - 1);
        uint256 price = PriceLib.getSpotPrice(parabolicSegments, s);
        uint256 expected = s * s / 1e18;
        assertEq(price, expected);
    }

    function testFuzz_getSpotPrice_linear_monotonicity(uint256 s1, uint256 s2) public view {
        s1 = bound(s1, 0, 499e18);
        s2 = bound(s2, s1, 999e18);
        uint256 p1 = PriceLib.getSpotPrice(linearSegments, s1);
        uint256 p2 = PriceLib.getSpotPrice(linearSegments, s2);
        assertTrue(p2 >= p1);
    }

    /*//////////////////////////////////////////////////////////////
                    SPOT PRICE: MULTI-SEGMENT ROUTING
    //////////////////////////////////////////////////////////////*/

    // ── Two-segment: LINEAR [0, 500) → PARABOLIC [500, 1000) ─

    function test_getSpotPrice_linearParabolic_inFirstSegment() public view {
        // supply=250 is in LINEAR → p(250) = 250
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, 250e18);
        assertEq(price, 250e18);
    }

    function test_getSpotPrice_linearParabolic_justBelowBoundary() public view {
        // supply=499 is still in LINEAR (< 500) → p(499) = 499
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, 499e18);
        assertEq(price, 499e18);
    }

    function test_getSpotPrice_linearParabolic_atBoundary() public view {
        // supply=500 routes to PARABOLIC (>= 500 && < 1000) → p(500) = 500² = 250000
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, BOUNDARY);
        assertEq(price, 250_000e18);
    }

    function test_getSpotPrice_linearParabolic_inSecondSegment() public view {
        // supply=600 is in PARABOLIC → p(600) = 600² = 360000
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, 600e18);
        assertEq(price, 360_000e18);
    }

    function test_getSpotPrice_linearParabolic_priceJumpsAtBoundary() public view {
        // Price is discontinuous at boundary: LINEAR p(499)=499, PARABOLIC p(500)=250000
        uint256 pBefore = PriceLib.getSpotPrice(linearParabolicSegments, 499e18);
        uint256 pAfter = PriceLib.getSpotPrice(linearParabolicSegments, BOUNDARY);
        assertTrue(pAfter > pBefore);
    }

    // ── Two-segment: LINEAR [0, 500) → LN [500, 1000) ────────

    function test_getSpotPrice_linearLn_inFirstSegment() public view {
        // supply=100 is in LINEAR → p(100) = 100
        uint256 price = PriceLib.getSpotPrice(linearLnSegments, 100e18);
        assertEq(price, 100e18);
    }

    function test_getSpotPrice_linearLn_atBoundary() public view {
        // supply=500 routes to LN → p(500) = ln(500 + 1) = ln(501) ≈ 6.2166...
        uint256 price = PriceLib.getSpotPrice(linearLnSegments, BOUNDARY);
        assertApproxEqRel(price, 6_216606191559280000, 0.01e18);
    }

    function test_getSpotPrice_linearLn_inSecondSegment() public view {
        // supply=750 in LN → p(750) = ln(750 + 1) = ln(751) ≈ 6.6214...
        uint256 price = PriceLib.getSpotPrice(linearLnSegments, 750e18);
        assertApproxEqRel(price, 6_621406197964908000, 0.01e18);
    }

    // ── Three-segment: LINEAR [0,200) → PARABOLIC [200,600) → EXP [600,700) ──

    function test_getSpotPrice_threeSegments_inLinear() public view {
        // supply=100 in LINEAR → p(100) = 100
        uint256 price = PriceLib.getSpotPrice(threeSegments, 100e18);
        assertEq(price, 100e18);
    }

    function test_getSpotPrice_threeSegments_atFirstBoundary() public view {
        // supply=200 routes to PARABOLIC → p(200) = 200² = 40000
        uint256 price = PriceLib.getSpotPrice(threeSegments, 200e18);
        assertEq(price, 40_000e18);
    }

    function test_getSpotPrice_threeSegments_inParabolic() public view {
        // supply=400 in PARABOLIC → p(400) = 400² = 160000
        uint256 price = PriceLib.getSpotPrice(threeSegments, 400e18);
        assertEq(price, 160_000e18);
    }

    function test_getSpotPrice_threeSegments_atSecondBoundary() public view {
        // supply=600 routes to EXPONENTIAL → p(600) = e^(0.01·600) = e^6 ≈ 403.429...
        uint256 price = PriceLib.getSpotPrice(threeSegments, 600e18);
        assertApproxEqRel(price, 403_428793492735000000, 0.01e18);
    }

    function test_getSpotPrice_threeSegments_inExponential() public view {
        // supply=650 in EXPONENTIAL → p(650) = e^(0.01·650) = e^6.5 ≈ 665.142...
        uint256 price = PriceLib.getSpotPrice(threeSegments, 650e18);
        assertApproxEqRel(price, 665_141633044576000000, 0.01e18);
    }

    function test_getSpotPrice_threeSegments_nearEnd() public view {
        // supply=699 in EXPONENTIAL → p(699) = e^(0.01·699) = e^6.99 ≈ 1089.62...
        uint256 price = PriceLib.getSpotPrice(threeSegments, 699e18);
        assertApproxEqRel(price, 1089_632897982380000000, 0.01e18);
    }

    // ── Multi-segment reverts ─────────────────────────────────

    function test_getSpotPrice_linearParabolic_reverts_beyondEnd() public {
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(linearParabolicSegments, MAX_SUPPLY);
    }

    function test_getSpotPrice_threeSegments_reverts_beyondEnd() public {
        // threeSegments ends at 700e18
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(threeSegments, 700e18);
    }

    // ── Multi-segment fuzz ────────────────────────────────────

    /*//////////////////////////////////////////////////////////////
                    SPOT PRICE: BOUNDARY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    // ── 1-wei precision at two-segment boundary ───────────────

    function test_getSpotPrice_linearParabolic_oneWeiBelow() public view {
        // supply = 500e18 - 1 (one wei below boundary) → still LINEAR
        uint256 s = BOUNDARY - 1;
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, s);
        // LINEAR: p(s) = s → should equal s
        assertEq(price, s);
    }

    function test_getSpotPrice_linearParabolic_exactBoundary() public view {
        // supply = 500e18 (exact boundary) → routes to PARABOLIC
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, BOUNDARY);
        // PARABOLIC: p(500) = 500² = 250000 — confirms >= check routes to segment 2
        assertEq(price, 250_000e18);
    }

    function test_getSpotPrice_linearParabolic_oneWeiAbove() public view {
        // supply = 500e18 + 1 (one wei above boundary) → PARABOLIC
        uint256 s = BOUNDARY + 1;
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, s);
        // PARABOLIC: p(s) = s² — should be very close to p(500)
        assertEq(price, s * s / 1e18);
    }

    // ── First and last valid supply ───────────────────────────

    function test_getSpotPrice_linearParabolic_atZero() public view {
        // supply=0 is the first valid point in the first segment
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, 0);
        assertEq(price, 0);
    }

    function test_getSpotPrice_linearParabolic_lastValidSupply() public view {
        // supply = 1000e18 - 1 is the last valid point (supplyEnd is exclusive)
        uint256 s = MAX_SUPPLY - 1;
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, s);
        assertEq(price, s * s / 1e18);
    }

    // ── Three-segment 1-wei boundaries ────────────────────────

    function test_getSpotPrice_threeSegments_oneWeiBeforeFirstBoundary() public view {
        // supply = 200e18 - 1 → still LINEAR
        uint256 s = 200e18 - 1;
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        // LINEAR: p(s) = s
        assertEq(price, s);
    }

    function test_getSpotPrice_threeSegments_oneWeiAfterFirstBoundary() public view {
        // supply = 200e18 + 1 → PARABOLIC
        uint256 s = 200e18 + 1;
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        // PARABOLIC: p(s) = s²
        assertEq(price, s * s / 1e18);
    }

    function test_getSpotPrice_threeSegments_oneWeiBeforeSecondBoundary() public view {
        // supply = 600e18 - 1 → still PARABOLIC
        uint256 s = 600e18 - 1;
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        // PARABOLIC: p(s) = s²
        assertEq(price, s * s / 1e18);
    }

    function test_getSpotPrice_threeSegments_oneWeiAfterSecondBoundary() public view {
        // supply = 600e18 + 1 → EXPONENTIAL
        uint256 s = 600e18 + 1;
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        // Should be very close to p(600) since 1 wei difference is negligible
        uint256 priceAtBoundary = PriceLib.getSpotPrice(threeSegments, 600e18);
        assertApproxEqRel(price, priceAtBoundary, 0.0001e18);
    }

    function test_getSpotPrice_threeSegments_firstValidSupply() public view {
        // supply=0 is valid (first segment starts at 0)
        uint256 price = PriceLib.getSpotPrice(threeSegments, 0);
        assertEq(price, 0);
    }

    function test_getSpotPrice_threeSegments_lastValidSupply() public view {
        // supply = 700e18 - 1 → last valid point in EXPONENTIAL
        uint256 s = 700e18 - 1;
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        // Should return without reverting and be close to p(700)
        assertTrue(price > 0);
    }

    // ── Exclusive end boundary reverts ─────────────────────────

    function test_getSpotPrice_threeSegments_reverts_atExactEnd() public {
        // 700e18 is supplyEnd of last segment → exclusive, reverts
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(threeSegments, 700e18);
    }

    function test_getSpotPrice_linearParabolic_reverts_atExactEnd() public {
        // 1000e18 is supplyEnd → exclusive
        vm.expectRevert(PriceLib.SUPPLY_OUT_OF_RANGE.selector);
        this.exposed_getSpotPrice(linearParabolicSegments, MAX_SUPPLY);
    }

    // ── Multi-segment fuzz ────────────────────────────────────

    function testFuzz_getSpotPrice_linearParabolic_routesCorrectly(uint256 s) public view {
        // In [0, 500): should match LINEAR p(s) = s
        // In [500, 1000): should match PARABOLIC p(s) = s²
        s = bound(s, 0, 999e18);
        uint256 price = PriceLib.getSpotPrice(linearParabolicSegments, s);
        if (s < BOUNDARY) {
            assertEq(price, s);
        } else {
            assertEq(price, s * s / 1e18);
        }
    }

    function testFuzz_getSpotPrice_threeSegments_alwaysRoutes(uint256 s) public view {
        // Any supply in [0, 700) should return a price without reverting
        s = bound(s, 0, 699e18);
        uint256 price = PriceLib.getSpotPrice(threeSegments, s);
        assertTrue(price >= 0); // just verifying no revert
    }
}