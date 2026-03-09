// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LnLib } from "./LnLib.sol";
import { SinLib } from "./SinLib.sol";
import { LinearLib } from "./LinearLib.sol";
import { SigmoidLib } from "./SigmoidLib.sol";
import { ParabolicLib } from "./ParabolicLib.sol";
import { ExponentialLib } from "./ExponentialLib.sol";

import { SD59x18, sd, convert } from "@prb-math/SD59x18.sol";
import { PiecewiseSegment, FormulaType } from "../Types.sol";

/// @title PriceLib
/// @notice Pure library for bonding curve price calculations with piecewise segment routing.
/// @dev Converts between uint256 (used by Curve.sol) and SD59x18 (used by formula libraries).
///      All uint256 values are 18-decimal fixed-point (same scale as SD59x18, but unsigned).
library PriceLib {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Zero tokens
    error ZERO_TOKENS();
    /// @notice Negative area
    error NEGATIVE_AREA();
    /// @notice Negative price
    error NEGATIVE_PRICE();
    /// @notice Supply out of range
    error SUPPLY_OUT_OF_RANGE();
    /// @notice Invalid formula type
    error INVALID_FORMULA_TYPE();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum iterations for binary search in calculateBuyTokens
    uint256 private constant MAX_ITERATIONS = 128;

    /// @notice Convergence tolerance for binary search (1 wei of 18-decimal token)
    SD59x18 private constant TOLERANCE = SD59x18.wrap(1);

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the spot price at a given supply position
    /// @param segments The piecewise curve segments
    /// @param supply The supply point (18 decimals)
    /// @return price The spot price (18 decimals)
    function getSpotPrice(
        PiecewiseSegment[] memory segments,
        uint256 supply
    ) internal pure returns (uint256 price) {
        SD59x18 s = sd(int256(supply));
        PiecewiseSegment memory seg = _findSegment(segments, supply);
        SD59x18 result = _spotPrice(seg, s);
        if (result < sd(0)) revert NEGATIVE_PRICE();
        // forge-lint: disable-next-line(unsafe-typecast)
        price = uint256(result.unwrap()); // safe: checked non-negative above
    }

    /// @notice Calculates how many tokens a buyer receives for a given collateral amount
    /// @dev Uses binary search to find tokensOut such that integrate(supply, supply + tokensOut) ≈ collateralIn.
    ///      The integral is monotonically increasing in tokensOut (for non-negative prices), so binary search works.
    /// @param segments The piecewise curve segments
    /// @param currentSupply The current token supply (18 decimals)
    /// @param collateralIn The collateral amount to spend (18 decimals)
    /// @return tokensOut The number of tokens to mint (18 decimals)
    function calculateBuyTokens(
        PiecewiseSegment[] memory segments,
        uint256 currentSupply,
        uint256 collateralIn
    ) internal pure returns (uint256 tokensOut) {
        if (collateralIn == 0) revert ZERO_TOKENS();

        SD59x18 target = sd(int256(collateralIn));
        SD59x18 supply = sd(int256(currentSupply));

        // Binary search bounds: 0 to maxSupply - currentSupply
        // Upper bound: use the last segment's supplyEnd as the absolute max
        uint256 maxSupply = segments[segments.length - 1].supplyEnd;
        SD59x18 lo = sd(0);
        SD59x18 hi = sd(int256(maxSupply - currentSupply));

        // If even buying all remaining tokens costs less than collateralIn, cap at max
        SD59x18 maxCost = _integrateAcrossSegments(segments, supply, supply + hi);
        if (maxCost <= target) {
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint256(hi.unwrap()); // safe: hi derived from uint256
        }

        // Binary search for tokensOut
        for (uint256 i; i < MAX_ITERATIONS; ++i) {
            SD59x18 mid = (lo + hi) / convert(2);
            SD59x18 cost = _integrateAcrossSegments(segments, supply, supply + mid);

            if (cost < target) {
                lo = mid;
            } else {
                hi = mid;
            }

            // Converged when hi - lo < 1 wei
            if (hi - lo <= TOLERANCE) break;
        }

        // Use lo (conservative — never overcharge the buyer)
        // forge-lint: disable-next-line(unsafe-typecast)
        tokensOut = uint256(lo.unwrap()); // safe: lo >= 0
    }

    /// @notice Calculates collateral returned when selling tokens
    /// @dev Integrates the price curve over the supply range being burned.
    /// @param segments The piecewise curve segments
    /// @param currentSupply The current token supply (18 decimals)
    /// @param tokensIn The number of tokens to sell (18 decimals)
    /// @return collateralOut The collateral to return (18 decimals)
    function calculateSellCollateral(
        PiecewiseSegment[] memory segments,
        uint256 currentSupply,
        uint256 tokensIn
    ) internal pure returns (uint256 collateralOut) {
        if (tokensIn == 0) revert ZERO_TOKENS();

        SD59x18 supply = sd(int256(currentSupply));
        SD59x18 tokens = sd(int256(tokensIn));

        // Integrate from (currentSupply - tokensIn) to currentSupply
        SD59x18 area = _integrateAcrossSegments(segments, supply - tokens, supply);
        if (area < sd(0)) revert NEGATIVE_AREA();
        // forge-lint: disable-next-line(unsafe-typecast)
        collateralOut = uint256(area.unwrap()); // safe: checked non-negative above
    }

    /// @notice Integrates the price curve across segment boundaries
    /// @param segments The piecewise curve segments
    /// @param fromSupply The lower supply bound (18 decimals)
    /// @param toSupply The upper supply bound (18 decimals)
    /// @return area The total area (18 decimals)
    function integrate(
        PiecewiseSegment[] memory segments,
        uint256 fromSupply,
        uint256 toSupply
    ) internal pure returns (uint256 area) {
        SD59x18 result = _integrateAcrossSegments(
            segments,
            sd(int256(fromSupply)),
            sd(int256(toSupply))
        );
        if (result < sd(0)) revert NEGATIVE_AREA();
        // forge-lint: disable-next-line(unsafe-typecast)
        area = uint256(result.unwrap()); // safe: checked non-negative above
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL ROUTING
    //////////////////////////////////////////////////////////////*/

    /// @dev Integrates the price function across piecewise segment boundaries.
    ///      Splits the integration range [sFrom, sTo] at each segment boundary.
    function _integrateAcrossSegments(
        PiecewiseSegment[] memory segments,
        SD59x18 sFrom,
        SD59x18 sTo
    ) private pure returns (SD59x18 total) {
        for (uint256 i; i < segments.length; ++i) {
            SD59x18 segStart = sd(int256(segments[i].supplyStart));
            SD59x18 segEnd = sd(int256(segments[i].supplyEnd));

            // Skip segments entirely before or after our range
            if (sTo <= segStart || sFrom >= segEnd) continue;

            // Clamp to segment boundaries
            SD59x18 lo = sFrom > segStart ? sFrom : segStart;
            SD59x18 hi = sTo < segEnd ? sTo : segEnd;

            total = total + _integrate(segments[i], lo, hi);
        }
    }

    /// @dev Routes to the correct formula library's spotPrice function
    function _spotPrice(PiecewiseSegment memory seg, SD59x18 s) private pure returns (SD59x18) {
        FormulaType ft = seg.formulaType;
        bytes memory params = seg.encodedParams;

        if (ft == FormulaType.LINEAR) return LinearLib.spotPrice(params, s);
        if (ft == FormulaType.LN) return LnLib.spotPrice(params, s);
        if (ft == FormulaType.SIN) return SinLib.spotPrice(params, s);
        if (ft == FormulaType.PARABOLIC) return ParabolicLib.spotPrice(params, s);
        if (ft == FormulaType.EXPONENTIAL) return ExponentialLib.spotPrice(params, s);
        if (ft == FormulaType.SIGMOID) return SigmoidLib.spotPrice(params, s);

        revert INVALID_FORMULA_TYPE();
    }

    /// @dev Routes to the correct formula library's integrate function
    function _integrate(PiecewiseSegment memory seg, SD59x18 sFrom, SD59x18 sTo) private pure returns (SD59x18) {
        FormulaType ft = seg.formulaType;
        bytes memory params = seg.encodedParams;

        if (ft == FormulaType.LINEAR) return LinearLib.integrate(params, sFrom, sTo);
        if (ft == FormulaType.LN) return LnLib.integrate(params, sFrom, sTo);
        if (ft == FormulaType.SIN) return SinLib.integrate(params, sFrom, sTo);
        if (ft == FormulaType.PARABOLIC) return ParabolicLib.integrate(params, sFrom, sTo);
        if (ft == FormulaType.EXPONENTIAL) return ExponentialLib.integrate(params, sFrom, sTo);
        if (ft == FormulaType.SIGMOID) return SigmoidLib.integrate(params, sFrom, sTo);

        revert INVALID_FORMULA_TYPE();
    }

    /// @dev Finds the segment that contains the given supply value
    function _findSegment(
        PiecewiseSegment[] memory segments,
        uint256 supply
    ) private pure returns (PiecewiseSegment memory) {
        for (uint256 i; i < segments.length; ++i) {
            if (supply >= segments[i].supplyStart && supply < segments[i].supplyEnd) {
                return segments[i];
            }
        }
        revert SUPPLY_OUT_OF_RANGE();
    }
}
