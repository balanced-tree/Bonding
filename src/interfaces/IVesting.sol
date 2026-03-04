// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IVesting
/// @notice Interface for the vesting contract
interface IVesting {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Initialized(address indexed curve);
    event VestingAdded(address indexed beneficiary, uint256 amount);
    event Claimed(address indexed beneficiary, uint256 amountClaimed);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_INITIALIZED();

    /// @notice Initializes the vesting contract with token and schedule parameters
    /// @dev Called once after deployment. Sets the token to vest and the global schedule.
    /// @param token The address of the ERC20 token subject to vesting
    /// @param cliff The cliff duration in seconds before any tokens become claimable
    /// @param duration The total vesting duration in seconds (from the start, inclusive of cliff)
    function initialize(address token, uint256 cliff, uint256 duration) external;

    /// @notice Adds a vesting allocation for a beneficiary
    /// @dev Creates or increases a vesting schedule for the given address
    /// @notice Only callable by the curve contract
    /// @param beneficiary The address that will receive vested tokens
    /// @param amount The total number of tokens allocated for vesting
    function addVesting(address beneficiary, uint256 amount) external;

    /// @notice Claims all currently vested tokens for the caller
    /// @dev Transfers the claimable amount to msg.sender and updates the claimed balance
    function claim() external;

    /// @notice Returns the amount of tokens currently claimable by a beneficiary
    /// @param beneficiary The address to query
    /// @return The number of tokens that can be claimed right now
    function claimable(address beneficiary) external view returns (uint256);
}
