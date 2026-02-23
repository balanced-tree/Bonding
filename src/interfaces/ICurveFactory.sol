// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ICurveFactory {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/
    struct CurveConfig {
        address curveToken;
        address collateralToken;
        PiecewiseConfig[] segments;
        VestingConfig vestingConfig;
    }

    struct PiecewiseConfig {
        uint256 supplyStart;
        uint256 supplyEnd;
        FormulaType formulaType;
        FormulaParams formulaParams;
    }

    struct FormulaParams {
        int256[] params;
    }

    struct VestingConfig {
        address vestingToken;
        uint256 cliffDuration;
        uint256 vestingDuration;
    }

    enum FormulaType {
        LINEAR,
        LN,
        SIN,
        PARABOLIC,
        EXPONENTIAL,
        SIGMOID
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CurveCreated(address indexed curve, address indexed creator);
    event VestingCreated(address indexed vesting, address indexed creator);
    event GraduationManagerCreated(address indexed graduationManager, address indexed creator);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();
    error INVALID_FEE_BPS();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}