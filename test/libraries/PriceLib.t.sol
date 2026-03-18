// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { PriceLib } from "../../src/libraries/PriceLib.sol";

contract PriceLibTest is BaseTest, Helpers {
    // ── External wrappers for revert testing ──────────────────
    // PriceLib functions are `internal`, so vm.expectRevert needs an external call boundary.

    function exposed_getSpotPrice(Types.PiecewiseSegment[] memory segments, uint256 supply) external pure returns (uint256) {
        return PriceLib.getSpotPrice(segments, supply);
    }

    function exposed_calculateBuyTokens(
        Types.PiecewiseSegment[] memory segments,
        uint256 currentSupply,
        uint256 collateralIn
    ) external pure returns (uint256) {
        return PriceLib.calculateBuyTokens(segments, currentSupply, collateralIn);
    }

    function exposed_calculateSellCollateral(
        Types.PiecewiseSegment[] memory segments,
        uint256 currentSupply,
        uint256 tokensIn
    ) external pure returns (uint256) {
        return PriceLib.calculateSellCollateral(segments, currentSupply, tokensIn);
    }

    function exposed_integrate(
        Types.PiecewiseSegment[] memory segments,
        uint256 fromSupply,
        uint256 toSupply
    ) external pure returns (uint256) {
        return PriceLib.integrate(segments, fromSupply, toSupply);
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

    /*//////////////////////////////////////////////////////////////
                    INTEGRATE: SINGLE-SEGMENT
    //////////////////////////////////////////////////////////////*/

    // ── LINEAR ∫s ds = s²/2 (exact — division by 2 is lossless in binary) ──

    function test_integrate_linear_zeroToHundred() public view {
        // ∫[0,100] s ds = 100²/2 = 5000
        uint256 area = PriceLib.integrate(linearSegments, 0, 100e18);
        assertEq(area, 5_000e18);
    }

    function test_integrate_linear_zeroToFiveHundred() public view {
        // ∫[0,500] s ds = 500²/2 = 125000
        uint256 area = PriceLib.integrate(linearSegments, 0, 500e18);
        assertEq(area, 125_000e18);
    }

    function test_integrate_linear_subRange() public view {
        // ∫[100,200] s ds = 200²/2 - 100²/2 = 20000 - 5000 = 15000
        uint256 area = PriceLib.integrate(linearSegments, 100e18, 200e18);
        assertEq(area, 15_000e18);
    }

    function test_integrate_linear_zeroWidth() public view {
        // ∫[50,50] = 0
        uint256 area = PriceLib.integrate(linearSegments, 50e18, 50e18);
        assertEq(area, 0);
    }

    // ── PARABOLIC ∫s² ds = s³/3 (±1 wei from division by 3) ───

    function test_integrate_parabolic_zeroToTen() public view {
        // ∫[0,10] s² ds = 10³/3 ≈ 333.333e18
        uint256 area = PriceLib.integrate(parabolicSegments, 0, 10e18);
        assertApproxEqAbs(area, 333_333333333333333333, 2);
    }

    function test_integrate_parabolic_zeroToHundred() public view {
        // ∫[0,100] s² ds = 100³/3 ≈ 333333.333e18
        uint256 area = PriceLib.integrate(parabolicSegments, 0, 100e18);
        assertApproxEqAbs(area, 333_333_333333333333333333, 2);
    }

    function test_integrate_parabolic_subRange() public view {
        // ∫[10,100] s² ds = (100³ - 10³)/3 = (1000000 - 1000)/3 = 999000/3 = 333000
        uint256 area = PriceLib.integrate(parabolicSegments, 10e18, 100e18);
        assertApproxEqAbs(area, 333_000_000000000000000000, 2);
    }

    // ── Single-segment additivity ──────────────────────────────

    function test_integrate_linear_additivity() public view {
        // ∫[0,200] = ∫[0,100] + ∫[100,200]
        uint256 full = PriceLib.integrate(linearSegments, 0, 200e18);
        uint256 first = PriceLib.integrate(linearSegments, 0, 100e18);
        uint256 second = PriceLib.integrate(linearSegments, 100e18, 200e18);
        assertEq(full, first + second);
    }

    function test_integrate_parabolic_additivity() public view {
        // ∫[0,200] ≈ ∫[0,100] + ∫[100,200]
        uint256 full = PriceLib.integrate(parabolicSegments, 0, 200e18);
        uint256 first = PriceLib.integrate(parabolicSegments, 0, 100e18);
        uint256 second = PriceLib.integrate(parabolicSegments, 100e18, 200e18);
        // SD59x18 truncation from /3 may introduce up to 1 wei discrepancy
        assertApproxEqAbs(full, first + second, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    INTEGRATE: CROSS-SEGMENT
    //////////////////////////////////////////////////////////////*/

    // ── Two-segment: LINEAR [0,500) → PARABOLIC [500,1000) ────

    function test_integrate_linearParabolic_withinFirstSegment() public view {
        // ∫[0,400] entirely in LINEAR = 400²/2 = 80000
        uint256 area = PriceLib.integrate(linearParabolicSegments, 0, 400e18);
        assertEq(area, 80_000e18);
    }

    function test_integrate_linearParabolic_withinSecondSegment() public view {
        // ∫[500,600] entirely in PARABOLIC = (600³ - 500³)/3
        uint256 area = PriceLib.integrate(linearParabolicSegments, 500e18, 600e18);
        // (216_000_000 - 125_000_000)/3 = 30_333_333.333...
        assertApproxEqRel(area, 30_333_333_333333333333333333, 0.0001e18);
    }

    function test_integrate_linearParabolic_spanningBoundary() public view {
        // ∫[400,600] = LINEAR∫[400,500] + PARABOLIC∫[500,600]
        //            = (500²-400²)/2 + (600³-500³)/3 = 45000 + 30333333.333
        uint256 area = PriceLib.integrate(linearParabolicSegments, 400e18, 600e18);
        // Verify via separate integrations
        uint256 linearPart = PriceLib.integrate(linearParabolicSegments, 400e18, 500e18);
        uint256 parabolicPart = PriceLib.integrate(linearParabolicSegments, 500e18, 600e18);
        // The library sums contributions in a single pass, which should
        // exactly equal the two separate calls (same arithmetic path)
        assertEq(area, linearPart + parabolicPart);
    }

    function test_integrate_linearParabolic_fullRange() public view {
        // ∫[0,999] — nearly the full curve
        uint256 area = PriceLib.integrate(linearParabolicSegments, 0, 999e18);
        // Should be LINEAR∫[0,500] + PARABOLIC∫[500,999]
        // LINEAR part = 125000e18 (exact)
        uint256 linearOnly = PriceLib.integrate(linearParabolicSegments, 0, 500e18);
        assertEq(linearOnly, 125_000e18);
        assertTrue(area > linearOnly);
    }

    function test_integrate_linearParabolic_crossSegmentAdditivity() public view {
        // ∫[0,600] = ∫[0,400] + ∫[400,600]
        uint256 full = PriceLib.integrate(linearParabolicSegments, 0, 600e18);
        uint256 first = PriceLib.integrate(linearParabolicSegments, 0, 400e18);
        uint256 second = PriceLib.integrate(linearParabolicSegments, 400e18, 600e18);
        assertEq(full, first + second);
    }

    function test_integrate_linearParabolic_crossSegmentAdditivity_atBoundary() public view {
        // Split exactly at the segment boundary: ∫[0,700] = ∫[0,500] + ∫[500,700]
        uint256 full = PriceLib.integrate(linearParabolicSegments, 0, 700e18);
        uint256 first = PriceLib.integrate(linearParabolicSegments, 0, 500e18);
        uint256 second = PriceLib.integrate(linearParabolicSegments, 500e18, 700e18);
        assertEq(full, first + second);
    }

    // ── Three-segment: LINEAR [0,200) → PARABOLIC [200,600) → EXP [600,700) ──

    function test_integrate_threeSegments_firstSegmentOnly() public view {
        // ∫[0,200] entirely in LINEAR = 200²/2 = 20000
        uint256 area = PriceLib.integrate(threeSegments, 0, 200e18);
        assertEq(area, 20_000e18);
    }

    function test_integrate_threeSegments_spanningFirstTwo() public view {
        // ∫[0,400] = LINEAR∫[0,200] + PARABOLIC∫[200,400]
        uint256 area = PriceLib.integrate(threeSegments, 0, 400e18);
        uint256 part1 = PriceLib.integrate(threeSegments, 0, 200e18);
        uint256 part2 = PriceLib.integrate(threeSegments, 200e18, 400e18);
        assertEq(area, part1 + part2);
    }

    function test_integrate_threeSegments_spanningAllThree() public view {
        // ∫[0,650] = ∫[0,200] + ∫[200,600] + ∫[600,650]
        uint256 full = PriceLib.integrate(threeSegments, 0, 650e18);
        uint256 part1 = PriceLib.integrate(threeSegments, 0, 200e18);
        uint256 part2 = PriceLib.integrate(threeSegments, 200e18, 600e18);
        uint256 part3 = PriceLib.integrate(threeSegments, 600e18, 650e18);
        assertApproxEqAbs(full, part1 + part2 + part3, 1);
    }

    function test_integrate_threeSegments_monotonicity() public view {
        // Wider range → larger integral (prices are non-negative)
        uint256 small = PriceLib.integrate(threeSegments, 0, 200e18);
        uint256 medium = PriceLib.integrate(threeSegments, 0, 400e18);
        uint256 large = PriceLib.integrate(threeSegments, 0, 650e18);
        assertTrue(large > medium);
        assertTrue(medium > small);
        assertTrue(small > 0);
    }

    // ── Integrate fuzz tests ────────────────────────────────────

    function testFuzz_integrate_linear_nonNegative(
        uint256 from,
        uint256 to
    ) public view {
        from = bound(from, 0, 998e18);
        to = bound(to, from, 999e18);
        uint256 area = PriceLib.integrate(linearSegments, from, to);
        assertTrue(area >= 0);
    }

    function testFuzz_integrate_linear_monotonicity(
        uint256 from,
        uint256 to1,
        uint256 to2
    ) public view {
        // Wider range → larger integral
        from = bound(from, 0, 500e18);
        to1 = bound(to1, from, 750e18);
        to2 = bound(to2, to1, 999e18);
        uint256 area1 = PriceLib.integrate(linearSegments, from, to1);
        uint256 area2 = PriceLib.integrate(linearSegments, from, to2);
        assertTrue(area2 >= area1);
    }

    function testFuzz_integrate_linear_additivity(
        uint256 a,
        uint256 b,
        uint256 c
    ) public view {
        // ∫[a,c] = ∫[a,b] + ∫[b,c]
        a = bound(a, 0, 300e18);
        b = bound(b, a, 600e18);
        c = bound(c, b, 999e18);
        uint256 full = PriceLib.integrate(linearSegments, a, c);
        uint256 first = PriceLib.integrate(linearSegments, a, b);
        uint256 second = PriceLib.integrate(linearSegments, b, c);
        assertEq(full, first + second);
    }

    function testFuzz_integrate_parabolic_additivity(
        uint256 a,
        uint256 b,
        uint256 c
    ) public view {
        // ∫[a,c] ≈ ∫[a,b] + ∫[b,c]  (±1 from /3 truncation)
        a = bound(a, 0, 300e18);
        b = bound(b, a, 600e18);
        c = bound(c, b, 999e18);
        uint256 full = PriceLib.integrate(parabolicSegments, a, c);
        uint256 first = PriceLib.integrate(parabolicSegments, a, b);
        uint256 second = PriceLib.integrate(parabolicSegments, b, c);
        assertApproxEqAbs(full, first + second, 1);
    }

    function testFuzz_integrate_linear_matchesFormula(
        uint256 from,
        uint256 to
    ) public view {
        // ∫[from,to] s ds = to²/2 - from²/2
        from = bound(from, 0, 500e18);
        to = bound(to, from, 999e18);
        uint256 area = PriceLib.integrate(linearSegments, from, to);
        // Manual uint256 division order differs from SD59x18 path — allow 1 wei
        uint256 expected = (to * to / 1e18 - from * from / 1e18) / 2;
        assertApproxEqAbs(area, expected, 1);
    }

    function testFuzz_integrate_linearParabolic_additivity(
        uint256 a,
        uint256 b,
        uint256 c
    ) public view {
        // Cross-segment additivity: ∫[a,c] = ∫[a,b] + ∫[b,c]
        a = bound(a, 0, 300e18);
        b = bound(b, a, 600e18);
        c = bound(c, b, 999e18);
        uint256 full = PriceLib.integrate(linearParabolicSegments, a, c);
        uint256 first = PriceLib.integrate(linearParabolicSegments, a, b);
        uint256 second = PriceLib.integrate(linearParabolicSegments, b, c);
        // Parabolic /3 truncation can introduce up to 1 wei discrepancy
        assertApproxEqAbs(full, first + second, 1);
    }

    function testFuzz_integrate_threeSegments_nonNegative(
        uint256 from,
        uint256 to
    ) public view {
        from = bound(from, 0, 698e18);
        to = bound(to, from, 699e18);
        uint256 area = PriceLib.integrate(threeSegments, from, to);
        assertTrue(area >= 0);
    }

    function testFuzz_integrate_threeSegments_additivity(
        uint256 a,
        uint256 b,
        uint256 c
    ) public view {
        a = bound(a, 0, 200e18);
        b = bound(b, a, 450e18);
        c = bound(c, b, 699e18);
        uint256 full = PriceLib.integrate(threeSegments, a, c);
        uint256 first = PriceLib.integrate(threeSegments, a, b);
        uint256 second = PriceLib.integrate(threeSegments, b, c);
        assertApproxEqAbs(full, first + second, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    CALCULATE BUY TOKENS
    //////////////////////////////////////////////////////////////*/

    // ── Linear single-segment: closed-form inverse ─────────────
    // For LINEAR p(s)=s at supply=0: ∫[0,t] = t²/2 = C  →  t = √(2C)
    // C = 5000  → t = √10000 = 100
    // C = 125000 → t = √250000 = 500

    function test_calculateBuyTokens_linear_fromZero_exact() public view {
        // C = 5000e18 → expect t ≈ 100e18
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, 5_000e18);
        assertApproxEqAbs(tokens, 100e18, 1);
    }

    function test_calculateBuyTokens_linear_fromZero_larger() public view {
        // C = 125000e18 → expect t ≈ 500e18
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, 125_000e18);
        assertApproxEqAbs(tokens, 500e18, 1);
    }

    function test_calculateBuyTokens_linear_fromNonZeroSupply() public view {
        // At supply=100: ∫[100, 100+t] = 100t + t²/2 = C
        // C = 15000 → t = -100 + √(100² + 2·15000) = -100 + √40000 = -100 + 200 = 100
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 100e18, 15_000e18);
        assertApproxEqAbs(tokens, 100e18, 1);
    }

    // ── Conservative property: never overcharges ────────────────

    function test_calculateBuyTokens_linear_neverOvercharges() public view {
        // integrate(0, tokensOut) should be ≤ collateralIn
        uint256 collateral = 5_000e18;
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, collateral);
        uint256 actualCost = PriceLib.integrate(linearSegments, 0, tokens);
        assertTrue(actualCost <= collateral);
    }

    function test_calculateBuyTokens_parabolic_neverOvercharges() public view {
        uint256 collateral = 10_000e18;
        uint256 tokens = PriceLib.calculateBuyTokens(parabolicSegments, 0, collateral);
        uint256 actualCost = PriceLib.integrate(parabolicSegments, 0, tokens);
        assertTrue(actualCost <= collateral);
    }

    // ── Precision: underspend is less than 1 token's spot price ─

    function test_calculateBuyTokens_linear_precision() public view {
        // The gap between collateralIn and actual cost should be < spotPrice(s + tokens)
        // i.e., the "leftover" collateral couldn't buy even 1 more wei of token
        uint256 collateral = 50_000e18;
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, collateral);
        uint256 actualCost = PriceLib.integrate(linearSegments, 0, tokens);
        uint256 gap = collateral - actualCost;
        uint256 nextPrice = PriceLib.getSpotPrice(linearSegments, tokens);
        // gap should be negligible relative to the next token's price
        assertTrue(gap <= nextPrice);
    }

    // ── Cap at max supply ───────────────────────────────────────

    function test_calculateBuyTokens_linear_capsAtMaxSupply() public view {
        // Max cost = ∫[0, 1000] = 500000. If collateral > max cost, get all remaining tokens.
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, 1_000_000e18);
        assertEq(tokens, MAX_SUPPLY);
    }

    function test_calculateBuyTokens_linear_capsAtMaxFromPartialSupply() public view {
        // At supply=900, remaining=100. Max cost = ∫[900,1000] = 95000.
        // Supplying 200000 should cap at 100 tokens.
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 900e18, 200_000e18);
        assertEq(tokens, 100e18);
    }

    // ── Zero collateral reverts ─────────────────────────────────

    function test_calculateBuyTokens_reverts_zeroCollateral() public {
        vm.expectRevert(PriceLib.ZERO_TOKENS.selector);
        this.exposed_calculateBuyTokens(linearSegments, 0, 0);
    }

    // ── Tiny collateral ─────────────────────────────────────────

    function test_calculateBuyTokens_linear_tinyCollateral() public view {
        // 1 wei of collateral — should return some tiny token amount without reverting
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, 1);
        // Binary search converges to a small value; just verify no revert and reasonable bound
        assertTrue(tokens < 1e18);
    }

    // ── Cross-segment: purchase spanning boundary ───────────────

    function test_calculateBuyTokens_linearParabolic_withinFirstSegment() public view {
        // At supply=0, buy with 80000e18. LINEAR ∫[0,400] = 80000.
        // Should get ≈ 400 tokens (all within linear segment)
        uint256 tokens = PriceLib.calculateBuyTokens(linearParabolicSegments, 0, 80_000e18);
        assertApproxEqAbs(tokens, 400e18, 1);
    }

    function test_calculateBuyTokens_linearParabolic_spanningBoundary() public view {
        // At supply=0, collateral = ∫[0,500] + ∫[500,600]
        // = 125000 + ~30333333 = ~30458333
        // Should get ≈ 600 tokens spanning the boundary
        uint256 collateral = PriceLib.integrate(linearParabolicSegments, 0, 600e18);
        uint256 tokens = PriceLib.calculateBuyTokens(linearParabolicSegments, 0, collateral);
        assertApproxEqAbs(tokens, 600e18, 1);
    }

    function test_calculateBuyTokens_linearParabolic_neverOvercharges() public view {
        uint256 collateral = 1_000_000e18;
        uint256 tokens = PriceLib.calculateBuyTokens(linearParabolicSegments, 200e18, collateral);
        uint256 actualCost = PriceLib.integrate(linearParabolicSegments, 200e18, 200e18 + tokens);
        assertTrue(actualCost <= collateral);
    }

    // ── Three-segment ───────────────────────────────────────────

    function test_calculateBuyTokens_threeSegments_spanningAll() public view {
        // Buy from supply=0 with enough to span all 3 segments
        uint256 collateral = PriceLib.integrate(threeSegments, 0, 650e18);
        uint256 tokens = PriceLib.calculateBuyTokens(threeSegments, 0, collateral);
        assertApproxEqAbs(tokens, 650e18, 1);
    }

    function test_calculateBuyTokens_threeSegments_neverOvercharges() public view {
        uint256 collateral = PriceLib.integrate(threeSegments, 0, 650e18);
        uint256 tokens = PriceLib.calculateBuyTokens(threeSegments, 0, collateral);
        uint256 actualCost = PriceLib.integrate(threeSegments, 0, tokens);
        assertTrue(actualCost <= collateral);
    }

    // ── Monotonicity: more collateral → more tokens ─────────────

    function test_calculateBuyTokens_linear_monotonicity() public view {
        uint256 tokens1 = PriceLib.calculateBuyTokens(linearSegments, 0, 1_000e18);
        uint256 tokens2 = PriceLib.calculateBuyTokens(linearSegments, 0, 5_000e18);
        uint256 tokens3 = PriceLib.calculateBuyTokens(linearSegments, 0, 50_000e18);
        assertTrue(tokens3 > tokens2);
        assertTrue(tokens2 > tokens1);
    }

    // ── Fuzz ────────────────────────────────────────────────────

    function testFuzz_calculateBuyTokens_linear_neverOvercharges(uint256 collateral) public view {
        // For any collateral, actual cost ≤ collateralIn
        collateral = bound(collateral, 1, 400_000e18);
        uint256 tokens = PriceLib.calculateBuyTokens(linearSegments, 0, collateral);
        if (tokens > 0 && tokens < MAX_SUPPLY) {
            uint256 actualCost = PriceLib.integrate(linearSegments, 0, tokens);
            assertTrue(actualCost <= collateral);
        }
    }

    function testFuzz_calculateBuyTokens_linear_monotonicity(uint256 c1, uint256 c2) public view {
        c1 = bound(c1, 1, 200_000e18);
        c2 = bound(c2, c1, 400_000e18);
        uint256 t1 = PriceLib.calculateBuyTokens(linearSegments, 0, c1);
        uint256 t2 = PriceLib.calculateBuyTokens(linearSegments, 0, c2);
        assertTrue(t2 >= t1);
    }

    function testFuzz_calculateBuyTokens_linearParabolic_neverOvercharges(uint256 collateral) public view {
        collateral = bound(collateral, 1, 100_000_000e18);
        uint256 supply = 100e18;
        uint256 tokens = PriceLib.calculateBuyTokens(linearParabolicSegments, supply, collateral);
        if (tokens > 0 && supply + tokens < MAX_SUPPLY) {
            uint256 actualCost = PriceLib.integrate(linearParabolicSegments, supply, supply + tokens);
            assertTrue(actualCost <= collateral);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    CALCULATE SELL COLLATERAL
    //////////////////////////////////////////////////////////////*/

    // ── Linear single-segment: known values ─────────────────────
    // sell(supply, tokens) = ∫[supply - tokens, supply]
    // For LINEAR p(s)=s: ∫[a,b] = b²/2 - a²/2

    function test_calculateSellCollateral_linear_sellAllFromHundred() public view {
        // At supply=100, sell 100 tokens: ∫[0,100] = 100²/2 = 5000
        uint256 collateral = PriceLib.calculateSellCollateral(linearSegments, 100e18, 100e18);
        assertEq(collateral, 5_000e18);
    }

    function test_calculateSellCollateral_linear_sellPartial() public view {
        // At supply=200, sell 100 tokens: ∫[100,200] = (200²-100²)/2 = 15000
        uint256 collateral = PriceLib.calculateSellCollateral(linearSegments, 200e18, 100e18);
        assertEq(collateral, 15_000e18);
    }

    function test_calculateSellCollateral_linear_sellAllFromFiveHundred() public view {
        // At supply=500, sell all 500: ∫[0,500] = 500²/2 = 125000
        uint256 collateral = PriceLib.calculateSellCollateral(linearSegments, 500e18, 500e18);
        assertEq(collateral, 125_000e18);
    }

    // ── Equivalence with integrate ──────────────────────────────

    function test_calculateSellCollateral_linear_matchesIntegrate() public view {
        // sell(supply=300, tokens=150) should equal integrate(150, 300)
        uint256 sellResult = PriceLib.calculateSellCollateral(linearSegments, 300e18, 150e18);
        uint256 integrateResult = PriceLib.integrate(linearSegments, 150e18, 300e18);
        assertEq(sellResult, integrateResult);
    }

    function test_calculateSellCollateral_parabolic_matchesIntegrate() public view {
        // sell(supply=100, tokens=50) should equal integrate(50, 100)
        uint256 sellResult = PriceLib.calculateSellCollateral(parabolicSegments, 100e18, 50e18);
        uint256 integrateResult = PriceLib.integrate(parabolicSegments, 50e18, 100e18);
        assertEq(sellResult, integrateResult);
    }

    // ── Parabolic: known value ──────────────────────────────────

    function test_calculateSellCollateral_parabolic_sellAllFromTen() public view {
        // At supply=10, sell 10 tokens: ∫[0,10] s² ds = 10³/3 ≈ 333.333e18
        uint256 collateral = PriceLib.calculateSellCollateral(parabolicSegments, 10e18, 10e18);
        assertApproxEqAbs(collateral, 333_333333333333333333, 2);
    }

    // ── Zero tokens reverts ─────────────────────────────────────

    function test_calculateSellCollateral_reverts_zeroTokens() public {
        vm.expectRevert(PriceLib.ZERO_TOKENS.selector);
        this.exposed_calculateSellCollateral(linearSegments, 100e18, 0);
    }

    // ── Sell back to zero supply ────────────────────────────────

    function test_calculateSellCollateral_linear_sellBackToZero() public view {
        // At supply=MAX_SUPPLY-1, sell everything back to 0
        uint256 supply = 999e18;
        uint256 collateral = PriceLib.calculateSellCollateral(linearSegments, supply, supply);
        // Should equal ∫[0, 999] = 999²/2
        uint256 expected = PriceLib.integrate(linearSegments, 0, supply);
        assertEq(collateral, expected);
    }

    // ── Cross-segment: sell spanning boundary ───────────────────

    function test_calculateSellCollateral_linearParabolic_withinSecondSegment() public view {
        // At supply=600, sell 50 (entirely in PARABOLIC [500,1000))
        // ∫[550, 600] = (600³-550³)/3
        uint256 collateral = PriceLib.calculateSellCollateral(linearParabolicSegments, 600e18, 50e18);
        uint256 expected = PriceLib.integrate(linearParabolicSegments, 550e18, 600e18);
        assertEq(collateral, expected);
    }

    function test_calculateSellCollateral_linearParabolic_spanningBoundary() public view {
        // At supply=600, sell 200 → ∫[400, 600] spans LINEAR and PARABOLIC
        uint256 collateral = PriceLib.calculateSellCollateral(linearParabolicSegments, 600e18, 200e18);
        uint256 expected = PriceLib.integrate(linearParabolicSegments, 400e18, 600e18);
        assertEq(collateral, expected);
    }

    function test_calculateSellCollateral_linearParabolic_sellAllFromBoundary() public view {
        // At supply=500 (exact boundary), sell all 500 → entirely LINEAR ∫[0,500] = 125000
        uint256 collateral = PriceLib.calculateSellCollateral(linearParabolicSegments, 500e18, 500e18);
        assertEq(collateral, 125_000e18);
    }

    // ── Three-segment sell ──────────────────────────────────────

    function test_calculateSellCollateral_threeSegments_withinExponential() public view {
        // At supply=650, sell 30 → entirely in EXPONENTIAL [600,700)
        uint256 collateral = PriceLib.calculateSellCollateral(threeSegments, 650e18, 30e18);
        uint256 expected = PriceLib.integrate(threeSegments, 620e18, 650e18);
        assertEq(collateral, expected);
    }

    function test_calculateSellCollateral_threeSegments_spanningAllThree() public view {
        // At supply=650, sell 650 → spans all 3 segments back to zero
        uint256 collateral = PriceLib.calculateSellCollateral(threeSegments, 650e18, 650e18);
        uint256 expected = PriceLib.integrate(threeSegments, 0, 650e18);
        assertEq(collateral, expected);
    }

    // ── Monotonicity: more tokens sold → more collateral ────────

    function test_calculateSellCollateral_linear_monotonicity() public view {
        uint256 c1 = PriceLib.calculateSellCollateral(linearSegments, 500e18, 50e18);
        uint256 c2 = PriceLib.calculateSellCollateral(linearSegments, 500e18, 200e18);
        uint256 c3 = PriceLib.calculateSellCollateral(linearSegments, 500e18, 500e18);
        assertTrue(c3 > c2);
        assertTrue(c2 > c1);
    }

    // ── Fuzz ────────────────────────────────────────────────────

    function testFuzz_calculateSellCollateral_linear_matchesIntegrate(uint256 supply, uint256 tokens) public view {
        supply = bound(supply, 1e18, 999e18);
        tokens = bound(tokens, 1e18, supply);
        uint256 sellResult = PriceLib.calculateSellCollateral(linearSegments, supply, tokens);
        uint256 integrateResult = PriceLib.integrate(linearSegments, supply - tokens, supply);
        assertEq(sellResult, integrateResult);
    }

    function testFuzz_calculateSellCollateral_linear_monotonicity(uint256 t1, uint256 t2) public view {
        // Selling more tokens from the same supply → more collateral
        t1 = bound(t1, 1e18, 250e18);
        t2 = bound(t2, t1, 500e18);
        uint256 c1 = PriceLib.calculateSellCollateral(linearSegments, 500e18, t1);
        uint256 c2 = PriceLib.calculateSellCollateral(linearSegments, 500e18, t2);
        assertTrue(c2 >= c1);
    }

    function testFuzz_calculateSellCollateral_linearParabolic_matchesIntegrate(
        uint256 supply,
        uint256 tokens
    ) public view {
        supply = bound(supply, 1e18, 999e18);
        tokens = bound(tokens, 1e18, supply);
        uint256 sellResult = PriceLib.calculateSellCollateral(linearParabolicSegments, supply, tokens);
        uint256 integrateResult = PriceLib.integrate(linearParabolicSegments, supply - tokens, supply);
        assertEq(sellResult, integrateResult);
    }

    /*//////////////////////////////////////////////////////////////
                    BUY-SELL ROUND-TRIP INVARIANTS
    //////////////////////////////////////////////////////////////*/

    // ── sell(buy(C)) ≤ C — no free money ────────────────────────

    function test_roundTrip_linear_sellAfterBuy_noProfit() public view {
        // Buy tokens with 5000e18, then sell them all back
        uint256 collateralIn = 5_000e18;
        uint256 tokensBought = PriceLib.calculateBuyTokens(linearSegments, 0, collateralIn);
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            linearSegments, tokensBought, tokensBought
        );
        assertTrue(collateralBack <= collateralIn);
    }

    function test_roundTrip_linear_sellAfterBuy_tightGap() public view {
        // The gap between collateralIn and collateralBack should be negligible
        uint256 collateralIn = 50_000e18;
        uint256 tokensBought = PriceLib.calculateBuyTokens(linearSegments, 0, collateralIn);
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            linearSegments, tokensBought, tokensBought
        );
        // Gap should be < spot price at the final supply (i.e., less than 1 token's worth)
        uint256 gap = collateralIn - collateralBack;
        uint256 spotAtEnd = PriceLib.getSpotPrice(linearSegments, tokensBought);
        assertTrue(gap <= spotAtEnd);
    }

    function test_roundTrip_parabolic_sellAfterBuy_noProfit() public view {
        uint256 collateralIn = 10_000e18;
        uint256 tokensBought = PriceLib.calculateBuyTokens(parabolicSegments, 0, collateralIn);
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            parabolicSegments, tokensBought, tokensBought
        );
        assertTrue(collateralBack <= collateralIn);
    }

    // ── Round-trip from non-zero supply ─────────────────────────

    function test_roundTrip_linear_fromNonZeroSupply() public view {
        uint256 supply = 200e18;
        uint256 collateralIn = 20_000e18;
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            linearSegments, supply, collateralIn
        );
        uint256 newSupply = supply + tokensBought;
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            linearSegments, newSupply, tokensBought
        );
        assertTrue(collateralBack <= collateralIn);
    }

    // ── Cross-segment round-trip ────────────────────────────────

    function test_roundTrip_linearParabolic_spanningBoundary() public view {
        // Buy from supply=400, spanning the 500 boundary into parabolic
        uint256 supply = 400e18;
        uint256 collateralIn = 50_000_000e18;
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            linearParabolicSegments, supply, collateralIn
        );
        uint256 newSupply = supply + tokensBought;
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            linearParabolicSegments, newSupply, tokensBought
        );
        assertTrue(collateralBack <= collateralIn);
    }

    function test_roundTrip_threeSegments_spanningAll() public view {
        // Buy from supply=0, spanning all 3 segments
        uint256 collateralIn = PriceLib.integrate(threeSegments, 0, 650e18);
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            threeSegments, 0, collateralIn
        );
        uint256 collateralBack = PriceLib.calculateSellCollateral(
            threeSegments, tokensBought, tokensBought
        );
        assertTrue(collateralBack <= collateralIn);
    }

    // ── buy(sell(T)) ≤ T — selling and rebuying loses tokens ────

    function test_roundTrip_linear_buyAfterSell_noExtraTokens() public view {
        // Start at supply=500, sell 200 tokens, then rebuy with collateral received
        uint256 supply = 500e18;
        uint256 tokensSold = 200e18;
        uint256 collateralReceived = PriceLib.calculateSellCollateral(
            linearSegments, supply, tokensSold
        );
        uint256 newSupply = supply - tokensSold; // 300
        uint256 tokensRebought = PriceLib.calculateBuyTokens(
            linearSegments, newSupply, collateralReceived
        );
        // Should get back ≤ original tokens (buy rounds down)
        assertTrue(tokensRebought <= tokensSold);
    }

    // ── Fuzz: sell(buy(C)) ≤ C ──────────────────────────────────

    function testFuzz_roundTrip_linear_sellAfterBuy_noProfit(
        uint256 collateralIn
    ) public view {
        collateralIn = bound(collateralIn, 1e18, 400_000e18);
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            linearSegments, 0, collateralIn
        );
        if (tokensBought > 0 && tokensBought < MAX_SUPPLY) {
            uint256 collateralBack = PriceLib.calculateSellCollateral(
                linearSegments, tokensBought, tokensBought
            );
            assertTrue(collateralBack <= collateralIn);
        }
    }

    function testFuzz_roundTrip_linear_fromRandomSupply(
        uint256 supply,
        uint256 collateralIn
    ) public view {
        supply = bound(supply, 0, 500e18);
        collateralIn = bound(collateralIn, 1e18, 200_000e18);
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            linearSegments, supply, collateralIn
        );
        if (tokensBought > 0 && supply + tokensBought < MAX_SUPPLY) {
            uint256 newSupply = supply + tokensBought;
            uint256 collateralBack = PriceLib.calculateSellCollateral(
                linearSegments, newSupply, tokensBought
            );
            assertTrue(collateralBack <= collateralIn);
        }
    }

    function testFuzz_roundTrip_linearParabolic_sellAfterBuy(
        uint256 collateralIn
    ) public view {
        collateralIn = bound(collateralIn, 1e18, 100_000_000e18);
        uint256 tokensBought = PriceLib.calculateBuyTokens(
            linearParabolicSegments, 0, collateralIn
        );
        if (tokensBought > 0 && tokensBought < MAX_SUPPLY) {
            uint256 collateralBack = PriceLib.calculateSellCollateral(
                linearParabolicSegments, tokensBought, tokensBought
            );
            assertTrue(collateralBack <= collateralIn);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    ERROR PATHS: NEGATIVE PRICE / AREA
    //////////////////////////////////////////////////////////////*/

    // ── NEGATIVE_PRICE: linear with negative slope, no intercept ─

    function test_getSpotPrice_reverts_negativePrice() public {
        // p(s) = -1·s + 0 → negative for any s > 0
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -1e18, 0);
        vm.expectRevert(PriceLib.NEGATIVE_PRICE.selector);
        this.exposed_getSpotPrice(segs, 10e18);
    }

    function test_getSpotPrice_negativeSlope_zeroSupplyIsZero() public pure {
        // p(0) = -1·0 + 0 = 0, which is non-negative → no revert
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -1e18, 0);
        uint256 price = PriceLib.getSpotPrice(segs, 0);
        assertEq(price, 0);
    }

    function test_getSpotPrice_reverts_negativePriceWithOffset() public {
        // p(s) = -2·s + 100 → negative for s > 50
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -2e18, 100e18);
        // At s=51, p = -2·51 + 100 = -2 → negative
        vm.expectRevert(PriceLib.NEGATIVE_PRICE.selector);
        this.exposed_getSpotPrice(segs, 51e18);
    }

    function test_getSpotPrice_negativeSlopeWithOffset_positiveRegion() public pure {
        // p(s) = -2·s + 100 → at s=10, p = -20 + 100 = 80
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -2e18, 100e18);
        uint256 price = PriceLib.getSpotPrice(segs, 10e18);
        assertEq(price, 80e18);
    }

    // ── NEGATIVE_AREA: integrate over a negative-price region ────

    function test_integrate_reverts_negativeArea() public {
        // p(s) = -1·s + 0 → ∫[0,100] = -100²/2 = -5000
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -1e18, 0);
        vm.expectRevert(PriceLib.NEGATIVE_AREA.selector);
        this.exposed_integrate(segs, 0, 100e18);
    }

    function test_integrate_negativeSlope_zeroWidthIsZero() public pure {
        // Even with negative slope, ∫[s,s] = 0 → no revert
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -1e18, 0);
        uint256 area = PriceLib.integrate(segs, 50e18, 50e18);
        assertEq(area, 0);
    }

    // ── NEGATIVE_AREA via calculateSellCollateral ────────────────

    function test_calculateSellCollateral_reverts_negativeArea() public {
        // Selling on a negative-slope curve → integrate returns negative
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1000e18, -1e18, 0);
        vm.expectRevert(PriceLib.NEGATIVE_AREA.selector);
        this.exposed_calculateSellCollateral(segs, 100e18, 50e18);
    }

    // ── Parabolic negative: p(s) = -s² ──────────────────────────

    function test_getSpotPrice_reverts_negativeParabolic() public {
        // p(s) = -1·s² → negative for any s > 0
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createParabolicSegment(0, 1000e18, -1e18, 0, 0);
        vm.expectRevert(PriceLib.NEGATIVE_PRICE.selector);
        this.exposed_getSpotPrice(segs, 10e18);
    }

    function test_integrate_reverts_negativeParabolicArea() public {
        // ∫[0,10] -s² ds = -10³/3 → negative
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createParabolicSegment(0, 1000e18, -1e18, 0, 0);
        vm.expectRevert(PriceLib.NEGATIVE_AREA.selector);
        this.exposed_integrate(segs, 0, 10e18);
    }
}