// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IGraduationManager
/// @notice Interface for the graduation manager
interface IGraduationManager {
    /// @notice Handles the graduation process for a bonding curve
    /// @dev Called by the Curve contract when the collateral threshold is reached.
    ///      Responsible for migrating liquidity to a DEX or other destination.
    /// @param curve The address of the graduating bonding curve
    /// @param collateral The address of the collateral token held by the curve
    /// @param tokenAmount The amount of bonding curve tokens to migrate
    /// @param collateralAmount The amount of collateral to migrate
    function graduate(address curve, address collateral, uint256 tokenAmount, uint256 collateralAmount) external;
}
