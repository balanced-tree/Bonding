// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title  ICurve
/// @notice Interface for the bonding curve contract
/// @author balanced-tree
interface ICurve {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct CurveConfig {
      uint256 maxThreshold;
      uint256 minThreshold;
      uint256 timeoutPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event curveInitialized(uint256 maxThreshold, uint256 minThreshold, uint256 timeoutPeriod);
    event collateralWithdrawn(address indexed user, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_INITIALIZED();

    error INVALID_TIMEOUT();

    error INVALID_THRESHOLD();

    error INVALID_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initialize(CurveConfig calldata config) external;
}