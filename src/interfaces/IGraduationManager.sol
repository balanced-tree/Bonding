// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IGraduationManager
/// @notice Interface for the graduation manager (Phase 3)
interface IGraduationManager {
    function graduate(
        address curve,
        address token,
        address collateral,
        uint256 tokenAmount,
        uint256 collateralAmount
    ) external;
}
