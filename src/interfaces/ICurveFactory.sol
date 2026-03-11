// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { CreateCurveParams } from "../Types.sol";

/// @title ICurveFactory
/// @notice Interface for the bonding curve factory
interface ICurveFactory {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CurveCreated(address indexed curve, address indexed token, address indexed creator, address vesting, address graduationManager);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_CONFIG();
    error INVALID_ADDRESS();
    error INVALID_FEE_BPS();
    error INVALID_SEGMENTS();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new bonding curve with its associated token and vesting contracts
    /// @dev Clones the token and curve implementations, initializes them with the provided
    ///      parameters, and registers the new curve in the factory's registry.
    /// @param params The full configuration for the new curve (token metadata, segments, vesting, etc.)
    /// @return curve The address of the newly deployed bonding curve
    /// @return token The address of the newly deployed token
    /// @return vesting The address of the newly deployed vesting contract
    /// @return graduationManager The address of the newly deployed graduation manager contract
    function createCurve(CreateCurveParams calldata params) external returns (address curve, address token, address vesting, address graduationManager);

    /// @notice Returns the total number of bonding curves created by this factory
    /// @return The count of registered curves
    function getCurveCount() external view returns (uint256);

    /// @notice Checks whether a given address is a curve deployed by this factory
    /// @param curve The address to check
    /// @return True if the address is a registered bonding curve, false otherwise
    function isCurve(address curve) external view returns (bool);

    /// @notice Returns all bonding curve addresses deployed by this factory
    /// @return An array of all registered curve addresses
    function getCurves() external view returns (address[] memory);

    /// @notice Returns the address of the token associated with a given curve
    /// @param curve The address of the curve
    /// @return The address of the token associated with the curve
    function getToken(address curve) external view returns (address);

    /// @notice Returns the address of the curve at a given index
    /// @param index The index of the curve
    /// @return The address of the curve at the given index
    function getCurve(uint256 index) external view returns (address);
}
