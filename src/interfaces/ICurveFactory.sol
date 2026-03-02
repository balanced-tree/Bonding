// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { CreateCurveParams } from "../Types.sol";

/// @title ICurveFactory
/// @notice Interface for the bonding curve factory
interface ICurveFactory {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CurveCreated(address indexed curve, address indexed token, address indexed creator);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();
    error INVALID_FEE_BPS();
    error INVALID_SEGMENTS();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createCurve(CreateCurveParams calldata params) external returns (address curve);
    function getCurves() external view returns (address[] memory);
    function getCurveCount() external view returns (uint256);
    function isCurve(address curve) external view returns (bool);
}
