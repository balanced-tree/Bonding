// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../../src/Types.sol" as Types;

// Testing
import { BaseTest } from "../BaseTest.t.sol";
import { Helpers } from "../utils/Helpers.sol";

// Libraries
import { PriceLib } from "../../src/libraries/PriceLib.sol";

// PRBMath
import { SD59x18, sd } from "@prb-math/SD59x18.sol";

contract PriceLibTest is BaseTest, Helpers {
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
        threeSegments.push(_createLinearSegment(0, 200e18));
        threeSegments.push(_createParabolicSegment(200e18, 600e18));
        threeSegments.push(_createExponentialSegment(600e18, 700e18));
    }
}