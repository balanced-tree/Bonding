// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd } from "@prb-math/SD59x18.sol";
import { LnParams } from "../Types.sol";

/// @title LnLib
/// @notice Price formula library for logarithmic bonding curves: p(s) = a * ln(s + c) + b
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = a * [(s+c)*ln(s+c) - (s+c)] + b*s.
///      Requires s + c > 0 for all supply values in the segment (enforced at curve creation).
library LnLib {
    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded LnParams (a, b, c)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: a * ln(s + c) + b
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        LnParams memory p = abi.decode(encodedParams, (LnParams));
        SD59x18 a = sd(p.a);
        SD59x18 b = sd(p.b);
        SD59x18 c = sd(p.c);

        // p(s) = a * ln(s + c) + b
        SD59x18 sc = s + c;
        price = a * sc.ln() + b;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(a * ln(s + c) + b)ds = a * [(s+c)*ln(s+c) - (s+c)] + b*s
    ///      Uses integration by parts: ∫ln(u)du = u*ln(u) - u
    /// @param encodedParams ABI-encoded LnParams (a, b, c)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(bytes memory encodedParams, SD59x18 sFrom, SD59x18 sTo) internal pure returns (SD59x18 area) {
        LnParams memory p = abi.decode(encodedParams, (LnParams));
        SD59x18 a = sd(p.a);
        SD59x18 b = sd(p.b);
        SD59x18 c = sd(p.c);

        // F(s) = a * [(s+c)*ln(s+c) - (s+c)] + b*s
        // area = F(sTo) - F(sFrom)
        area = _antiderivative(a, b, c, sTo) - _antiderivative(a, b, c, sFrom);
    }

    /// @dev Evaluates the antiderivative F(s) = a * [(s+c)*ln(s+c) - (s+c)] + b*s
    function _antiderivative(SD59x18 a, SD59x18 b, SD59x18 c, SD59x18 s) private pure returns (SD59x18) {
        SD59x18 sc = s + c;
        // a * [sc * ln(sc) - sc] + b * s
        return a * (sc * sc.ln() - sc) + b * s;
    }
}
