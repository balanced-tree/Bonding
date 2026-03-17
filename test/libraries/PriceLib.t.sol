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
}