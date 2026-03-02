// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IVesting
/// @notice Interface for the vesting contract (Phase 4)
interface IVesting {
    function initialize(address token, uint256 cliff, uint256 duration) external;
    function addVesting(address beneficiary, uint256 amount) external;
    function claim() external;
    function claimable(address beneficiary) external view returns (uint256);
}
