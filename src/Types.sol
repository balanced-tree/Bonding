// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Types
/// @notice Shared types used across the bonding curve protocol

enum FormulaType {
    LINEAR,
    LN,
    SIN,
    PARABOLIC,
    EXPONENTIAL,
    SIGMOID
}

/*//////////////////////////////////////////////////////////////
                        FORMULA PARAM STRUCTS
//////////////////////////////////////////////////////////////*/

/// @notice Parameters for linear price formula: p(s) = m * s + b
/// @param m Slope (SD59x18)
/// @param b Intercept (SD59x18)
struct LinearParams {
    int256 m;
    int256 b;
}

/// @notice Parameters for logarithmic price formula: p(s) = a * ln(s + c) + b
/// @param a Scale factor (SD59x18)
/// @param b Offset (SD59x18)
/// @param c Horizontal shift — must satisfy s + c > 0 for all s in segment (SD59x18)
struct LnParams {
    int256 a;
    int256 b;
    int256 c;
}

/// @notice Parameters for sinusoidal price formula: p(s) = a * sin(w * s + phi) + b
/// @param a Amplitude (SD59x18)
/// @param w Angular frequency (SD59x18)
/// @param phi Phase shift (SD59x18)
/// @param b Vertical offset (SD59x18)
struct SinParams {
    int256 a;
    int256 w;
    int256 phi;
    int256 b;
}

/// @notice Parameters for parabolic price formula: p(s) = a * s^2 + b * s + c
/// @param a Quadratic coefficient (SD59x18)
/// @param b Linear coefficient (SD59x18)
/// @param c Constant term (SD59x18)
struct ParabolicParams {
    int256 a;
    int256 b;
    int256 c;
}

/// @notice Parameters for exponential price formula: p(s) = a * e^(k * s) + b
/// @param a Scale factor (SD59x18)
/// @param k Growth rate (SD59x18)
/// @param b Offset (SD59x18)
struct ExponentialParams {
    int256 a;
    int256 k;
    int256 b;
}

/// @notice Parameters for sigmoid price formula: p(s) = maxVal / (1 + e^(-k * (s - s0))) + b
/// @param maxVal Maximum value, i.e. L in the standard sigmoid form (SD59x18)
/// @param k Steepness (SD59x18)
/// @param s0 Midpoint — supply value at sigmoid center (SD59x18)
/// @param b Vertical offset (SD59x18)
struct SigmoidParams {
    int256 maxVal;
    int256 k;
    int256 s0;
    int256 b;
}

/*//////////////////////////////////////////////////////////////
                        PIECEWISE SEGMENT
//////////////////////////////////////////////////////////////*/

/// @notice A single segment of a piecewise bonding curve
/// @dev `encodedParams` holds abi.encode'd formula-specific params struct
///      (e.g. abi.encode(LinearParams({m: ..., b: ...})) for LINEAR).
///      Each formula library decodes its own param type.
struct PiecewiseSegment {
    uint256 supplyStart; // Token supply where this segment begins (18 decimals)
    uint256 supplyEnd; // Token supply where this segment ends (18 decimals)
    FormulaType formulaType;
    bytes encodedParams;
}

struct CurveParams {
    address collateralToken;
    PiecewiseSegment[] segments;
    uint256 maxThreshold; // Collateral threshold for graduation (0 = no graduation)
    uint256 maxBuyPerTx; // Max tokens purchasable per tx (0 = unlimited)
    uint256 maxSellPerTx; // Max tokens sellable per tx (0 = unlimited)
}

struct VestingConfig {
    uint256 cliffDuration;
    uint256 vestingDuration;
}

struct CreateCurveParams {
    string name;
    string symbol;
    uint8 decimals;
    CurveParams curveParams;
    VestingConfig vestingConfig;
}
