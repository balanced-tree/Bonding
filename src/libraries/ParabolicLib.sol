// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd, convert } from "@prb-math/SD59x18.sol";
import { ParabolicParams } from "../Types.sol";

/// @title ParabolicLib
/// @notice Price formula library for parabolic bonding curves: p(s) = a * s² + b * s + c
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = a*s³/3 + b*s²/2 + c*s.
library ParabolicLib {
    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded ParabolicParams (a, b, c)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: a * s² + b * s + c
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        ParabolicParams memory p = abi.decode(encodedParams, (ParabolicParams));
        SD59x18 a = sd(p.a);
        SD59x18 b = sd(p.b);
        SD59x18 c = sd(p.c);

        // p(s) = a * s² + b * s + c
        price = a * s * s + b * s + c;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(a*s² + b*s + c)ds = a*s³/3 + b*s²/2 + c*s, evaluated as F(sTo) - F(sFrom)
    /// @param encodedParams ABI-encoded ParabolicParams (a, b, c)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(bytes memory encodedParams, SD59x18 sFrom, SD59x18 sTo) internal pure returns (SD59x18 area) {
        ParabolicParams memory p = abi.decode(encodedParams, (ParabolicParams));
        SD59x18 a = sd(p.a);
        SD59x18 b = sd(p.b);
        SD59x18 c = sd(p.c);

        // F(s) = a*s³/3 + b*s²/2 + c*s
        // area = F(sTo) - F(sFrom)
        area = _antiderivative(a, b, c, sTo) - _antiderivative(a, b, c, sFrom);
    }

    /// @dev Evaluates the antiderivative F(s) = a*s³/3 + b*s²/2 + c*s
    function _antiderivative(SD59x18 a, SD59x18 b, SD59x18 c, SD59x18 s) private pure returns (SD59x18) {
        SD59x18 two = convert(2);
        SD59x18 three = convert(3);
        return (a * s * s * s) / three + (b * s * s) / two + c * s;
    }
}
