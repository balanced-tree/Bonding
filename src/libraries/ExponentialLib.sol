// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd } from "@prb-math/SD59x18.sol";
import { ExponentialParams } from "../Types.sol";

/// @title ExponentialLib
/// @notice Price formula library for exponential bonding curves: p(s) = a * e^(k * s) + b
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = a/k * e^(k*s) + b*s.
///      Uses PRBMath's exp() which supports inputs in range (~-41.45, 133.08).
library ExponentialLib {
    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded ExponentialParams (a, k, b)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: a * e^(k * s) + b
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        ExponentialParams memory p = abi.decode(encodedParams, (ExponentialParams));
        SD59x18 a = sd(p.a);
        SD59x18 k = sd(p.k);
        SD59x18 b = sd(p.b);

        // p(s) = a * e^(k * s) + b
        price = a * (k * s).exp() + b;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(a * e^(k*s) + b)ds = a/k * e^(k*s) + b*s, evaluated as F(sTo) - F(sFrom)
    /// @param encodedParams ABI-encoded ExponentialParams (a, k, b)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(bytes memory encodedParams, SD59x18 sFrom, SD59x18 sTo) internal pure returns (SD59x18 area) {
        ExponentialParams memory p = abi.decode(encodedParams, (ExponentialParams));
        SD59x18 a = sd(p.a);
        SD59x18 k = sd(p.k);
        SD59x18 b = sd(p.b);

        // F(s) = a/k * e^(k*s) + b*s
        // area = F(sTo) - F(sFrom)
        SD59x18 aOverK = a / k;

        SD59x18 fTo = aOverK * (k * sTo).exp() + b * sTo;
        SD59x18 fFrom = aOverK * (k * sFrom).exp() + b * sFrom;
        area = fTo - fFrom;
    }
}
