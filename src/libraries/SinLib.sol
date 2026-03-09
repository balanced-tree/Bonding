// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SD59x18, sd } from "@prb-math/SD59x18.sol";
import { SinParams } from "../Types.sol";
import { Trigonometry } from "solidity-trigonometry/Trigonometry.sol";

/// @title SinLib
/// @notice Price formula library for sinusoidal bonding curves: p(s) = a * sin(w * s + phi) + b
/// @dev All inputs and outputs use SD59x18 (signed 59.18 fixed-point).
///      The integral ∫p(s)ds = -a/w * cos(w*s + phi) + b*s.
///      Uses solidity-trigonometry for on-chain sin/cos (lookup table, 1e18-scaled).
library SinLib {
    uint256 private constant TWO_PI = Trigonometry.TWO_PI;

    /// @notice Computes the spot price at a given supply
    /// @param encodedParams ABI-encoded SinParams (a, w, phi, b)
    /// @param s The supply point (SD59x18)
    /// @return price The price at supply s: a * sin(w * s + phi) + b
    function spotPrice(bytes memory encodedParams, SD59x18 s) internal pure returns (SD59x18 price) {
        SinParams memory p = abi.decode(encodedParams, (SinParams));
        SD59x18 a = sd(p.a);
        SD59x18 w = sd(p.w);
        SD59x18 phi = sd(p.phi);
        SD59x18 b = sd(p.b);

        // p(s) = a * sin(w * s + phi) + b
        SD59x18 angle = w * s + phi;
        SD59x18 sinVal = _sin(angle);
        price = a * sinVal + b;
    }

    /// @notice Computes the definite integral of p(s) from sFrom to sTo
    /// @dev ∫(a * sin(w*s + phi) + b)ds = [-a/w * cos(w*s + phi) + b*s]
    /// @param encodedParams ABI-encoded SinParams (a, w, phi, b)
    /// @param sFrom Lower supply bound (SD59x18)
    /// @param sTo Upper supply bound (SD59x18)
    /// @return area The area under the price curve between sFrom and sTo
    function integrate(
        bytes memory encodedParams,
        SD59x18 sFrom,
        SD59x18 sTo
    ) internal pure returns (SD59x18 area) {
        SinParams memory p = abi.decode(encodedParams, (SinParams));
        SD59x18 a = sd(p.a);
        SD59x18 w = sd(p.w);
        SD59x18 phi = sd(p.phi);
        SD59x18 b = sd(p.b);

        // F(s) = -a/w * cos(w*s + phi) + b*s
        // area = F(sTo) - F(sFrom)
        SD59x18 negAOverW = -a / w;

        SD59x18 fTo = negAOverW * _cos(w * sTo + phi) + b * sTo;
        SD59x18 fFrom = negAOverW * _cos(w * sFrom + phi) + b * sFrom;
        area = fTo - fFrom;
    }

    /// @dev Wraps Trigonometry.sin() for SD59x18 angles.
    ///      Normalizes negative angles to [0, 2π) range.
    function _sin(SD59x18 angle) private pure returns (SD59x18) {
        return sd(Trigonometry.sin(_normalizeAngle(angle)));
    }

    /// @dev Wraps Trigonometry.cos() for SD59x18 angles.
    function _cos(SD59x18 angle) private pure returns (SD59x18) {
        return sd(Trigonometry.cos(_normalizeAngle(angle)));
    }

    /// @dev Converts an SD59x18 angle (possibly negative) to a uint256 in [0, 2π).
    ///      The Trigonometry library internally does `_angle % TWO_PI`, so we only
    ///      need to handle the sign conversion.
    function _normalizeAngle(SD59x18 angle) private pure returns (uint256) {
        int256 raw = angle.unwrap();
        if (raw >= 0) return uint256(raw);

        // For negative angles: normalize to [0, 2π)
        // e.g., -0.5 rad → (2π - 0.5) rad
        int256 twoPi = int256(TWO_PI);
        int256 normalized = raw % twoPi;
        if (normalized < 0) normalized += twoPi;
        return uint256(normalized);
    }
}
