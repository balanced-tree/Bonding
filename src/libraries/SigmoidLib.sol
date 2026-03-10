// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd } from "@prb-math/SD59x18.sol";
import { SigmoidParams } from "../Types.sol";

/// @title SigmoidLib
/// @notice Price formula library for sigmoid bonding curves: p(s) = maxVal / (1 + e^(-k * (s - s0))) + b
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = maxVal/k * ln(1 + e^(k*(s - s0))) + b*s.
///      Uses PRBMath's exp() and ln(). The exp() input must be in (~-41.45, 133.08).
library SigmoidLib {
    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded SigmoidParams (maxVal, k, s0, b)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: maxVal / (1 + e^(-k * (s - s0))) + b
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        SigmoidParams memory p = abi.decode(encodedParams, (SigmoidParams));
        SD59x18 maxVal = sd(p.maxVal);
        SD59x18 k = sd(p.k);
        SD59x18 s0 = sd(p.s0);
        SD59x18 b = sd(p.b);

        // p(s) = maxVal / (1 + e^(-k * (s - s0))) + b
        SD59x18 one = sd(1e18);
        SD59x18 expTerm = (-k * (s - s0)).exp();
        price = maxVal / (one + expTerm) + b;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(maxVal / (1 + e^(-k*(s-s0))) + b)ds = maxVal/k * ln(1 + e^(k*(s-s0))) + b*s
    ///      Derivation: substitute u = k*(s-s0), then ∫1/(1+e^(-u))du = ln(1+e^u)
    /// @param encodedParams ABI-encoded SigmoidParams (maxVal, k, s0, b)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(bytes memory encodedParams, SD59x18 sFrom, SD59x18 sTo) internal pure returns (SD59x18 area) {
        SigmoidParams memory p = abi.decode(encodedParams, (SigmoidParams));
        SD59x18 maxVal = sd(p.maxVal);
        SD59x18 k = sd(p.k);
        SD59x18 s0 = sd(p.s0);
        SD59x18 b = sd(p.b);

        // F(s) = maxVal/k * ln(1 + e^(k*(s - s0))) + b*s
        // area = F(sTo) - F(sFrom)
        SD59x18 maxValOverK = maxVal / k;

        area = _antiderivative(maxValOverK, k, s0, b, sTo) - _antiderivative(maxValOverK, k, s0, b, sFrom);
    }

    /// @dev Evaluates the antiderivative F(s) = maxVal/k * ln(1 + e^(k*(s - s0))) + b*s
    /// @param maxValOverK Precomputed maxVal / k
    function _antiderivative(
        SD59x18 maxValOverK,
        SD59x18 k,
        SD59x18 s0,
        SD59x18 b,
        SD59x18 s
    )
        private
        pure
        returns (SD59x18)
    {
        SD59x18 one = sd(1e18);
        // ln(1 + e^(k*(s - s0)))
        SD59x18 expTerm = (k * (s - s0)).exp();
        SD59x18 lnTerm = (one + expTerm).ln();
        return maxValOverK * lnTerm + b * s;
    }
}
