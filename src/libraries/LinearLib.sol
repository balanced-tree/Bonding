// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd, convert } from "@prb-math/SD59x18.sol";
import { LinearParams } from "../Types.sol";

/// @title LinearLib
/// @notice Price formula library for linear bonding curves: p(s) = m * s + b
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = m*s²/2 + b*s is used by PriceLib to calculate
///      the collateral cost of moving between two supply positions.
library LinearLib {
    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded LinearParams (m, b)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: m * s + b
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        LinearParams memory p = abi.decode(encodedParams, (LinearParams));
        SD59x18 m = sd(p.m);
        SD59x18 b = sd(p.b);
        price = m * s + b;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(m*s + b)ds = m*s²/2 + b*s, evaluated as F(sTo) - F(sFrom)
    /// @param encodedParams ABI-encoded LinearParams (m, b)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(
        bytes memory encodedParams,
        SD59x18 sFrom,
        SD59x18 sTo
    ) internal pure returns (SD59x18 area) {
        LinearParams memory p = abi.decode(encodedParams, (LinearParams));
        SD59x18 m = sd(p.m);
        SD59x18 b = sd(p.b);
        SD59x18 two = convert(2);

        // F(s) = m * s² / 2 + b * s
        // area = F(sTo) - F(sFrom)
        SD59x18 fTo = (m * sTo * sTo) / two + b * sTo;
        SD59x18 fFrom = (m * sFrom * sFrom) / two + b * sFrom;
        area = fTo - fFrom;
    }
}
