// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ICurveFactory } from "../interfaces/ICurveFactory.sol";

// OpenZeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CurveFactory
/// @notice Factory for creating Curve contracts
/// @author balanced-tree
contract CurveFactory is ICurveFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Clones for address;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public protocolTreasury;

    address public immutable CURVE_IMPLEMENTATION;
    address public immutable VESTING_IMPLEMENTATION;
    address public immutable GRADUATION_MANAGER_IMPLEMENTATION;
    
    EnumerableSet.AddressSet private _curves;
    EnumerableSet.AddressSet private _vestings;
    EnumerableSet.AddressSet private _graduationManagers;

    uint256 public protocolFeeBps;
    // Constant for basis points precision (100% = 10,000 bps)
    uint256 private constant BPS_PRECISION = 10_000;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
      address _curveImplementation,
      address _vestingImplementation,
      address _graduationManagerImplementation,
      address _protocolTreasury,
      uint256 _protocolFeeBps
    ) {
        if (
          _curveImplementation == address(0) ||
          _vestingImplementation == address(0) ||
          _graduationManagerImplementation == address(0) ||
          _protocolTreasury == address(0)
        ) {
            revert INVALID_ADDRESS();
        }

        if (_protocolFeeBps >= BPS_PRECISION || _protocolFeeBps == 0) {
            revert INVALID_FEE_BPS();
        }

        CURVE_IMPLEMENTATION = _curveImplementation;
        VESTING_IMPLEMENTATION = _vestingImplementation;
        GRADUATION_MANAGER_IMPLEMENTATION = _graduationManagerImplementation;

        protocolTreasury = _protocolTreasury;
        protocolFeeBps = _protocolFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                              CURVE CREATION
    //////////////////////////////////////////////////////////////*/
}