// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IVesting
/// @notice Interface for the vesting contract
interface IVesting {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice The schedule for a beneficiary's vested tokens
    /// @param totalAmount The total amount of tokens allocated for vesting
    /// @param startTime The start time of the vesting
    /// @param claimed The amount of tokens claimed by the beneficiary
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 claimed;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when the vesting contract is initialized
    event Initialized(address indexed curve);

    /// @notice Emitted when a vesting allocation is added for a beneficiary
    event VestingAdded(address indexed beneficiary, uint256 amount);

    /// @notice Emitted when a beneficiary claims their vested tokens
    event Claimed(address indexed beneficiary, uint256 amountClaimed);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ONLY_CURVE();
    error INVALID_DURATION();
    error NOTHING_TO_CLAIM();
    error INVALID_BENEFICIARY();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the vesting contract with token and schedule parameters
    /// @dev Called once after deployment. Sets the token to vest and the global schedule.
    /// @param token The address of the ERC20 token subject to vesting
    /// @param curve The address of the bonding curve (only caller allowed to addVesting)
    /// @param cliff The cliff duration in seconds before any tokens become claimable
    /// @param duration The total vesting duration in seconds (from the start, inclusive of cliff)
    function initialize(address token, address curve, uint256 cliff, uint256 duration) external;

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
