// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

// Contracts
import { IVesting } from "../interfaces/IVesting.sol";

/// @title Vesting
/// @notice Linear vesting with cliff for tokens purchased through a bonding curve.
///         Each beneficiary has a single schedule; additional buys increase the total amount.
contract Vesting is Initializable, IVesting {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public token;
    address public curve;

    uint256 public cliffDuration;
    uint256 public vestingDuration;

    mapping(address beneficiary => VestingSchedule schedule) public schedules;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyCurve() {
        if (msg.sender != curve) revert ONLY_CURVE();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @dev Locks the implementation contract from being initialized
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVesting
    function initialize(address _token, address _curve, uint256 _cliff, uint256 _duration) external initializer {
        if (_duration == 0) revert INVALID_DURATION();

        token = _token;
        curve = _curve;
        cliffDuration = _cliff;
        vestingDuration = _duration;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVesting
    function addVesting(address beneficiary, uint256 amount) external onlyCurve {
        if (beneficiary == address(0)) revert INVALID_BENEFICIARY();

        VestingSchedule storage schedule = schedules[beneficiary];

        // First allocation sets the start time
        if (schedule.startTime == 0) {
            schedule.startTime = block.timestamp;
        }

        schedule.totalAmount += amount;

        emit VestingAdded(beneficiary, amount);
    }

    /// @inheritdoc IVesting
    function claim() external {
        uint256 amount = _claimable(msg.sender);
        if (amount == 0) revert NOTHING_TO_CLAIM();

        schedules[msg.sender].claimed += amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVesting
    function claimable(address beneficiary) external view returns (uint256) {
        return _claimable(beneficiary);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculates the amount currently claimable by a beneficiary
    ///      unlocked = total * (elapsed - cliff) / vestingDuration, capped at total
    ///      claimable = unlocked - claimed
    function _claimable(address beneficiary) internal view returns (uint256) {
        VestingSchedule storage schedule = schedules[beneficiary];

        if (schedule.totalAmount == 0) return 0;

        uint256 elapsed = block.timestamp - schedule.startTime;

        // Before cliff: nothing unlocked
        if (elapsed < cliffDuration) return 0;

        uint256 vestedElapsed = elapsed - cliffDuration;

        uint256 unlocked;
        if (vestedElapsed >= vestingDuration) {
            // Fully vested
            unlocked = schedule.totalAmount;
        } else {
            // Linear unlock
            unlocked = (schedule.totalAmount * vestedElapsed) / vestingDuration;
        }

        return unlocked - schedule.claimed;
    }
}
