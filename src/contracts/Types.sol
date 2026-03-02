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

struct FormulaParams {
    int256[] params; // SD59x18-encoded parameters, meaning varies by FormulaType
}

struct PiecewiseSegment {
    uint256 supplyStart; // Token supply where this segment begins (18 decimals)
    uint256 supplyEnd; // Token supply where this segment ends (18 decimals)
    FormulaType formulaType;
    FormulaParams formulaParams;
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
