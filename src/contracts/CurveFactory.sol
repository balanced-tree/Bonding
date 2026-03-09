// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
  CurveParams,
  VestingConfig,
  CreateCurveParams,
  PiecewiseSegment
} from "../Types.sol";
import { Curve } from "./Curve.sol";
import { Vesting } from "./Vesting.sol";
import { BondingToken } from "./BondingToken.sol";
import { GraduationManager } from "./GraduationManager.sol";
import { ICurveFactory } from "../interfaces/ICurveFactory.sol";

// OpenZeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title CurveFactory
/// @notice Factory for creating Curve contracts
/// @author balanced-tree
contract CurveFactory is ICurveFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public protocolTreasury;

    address public immutable CURVE_IMPLEMENTATION;
    address public immutable TOKEN_IMPLEMENTATION;
    address public immutable VESTING_IMPLEMENTATION;
    address public immutable GRADUATION_MANAGER_IMPLEMENTATION;

    EnumerableSet.AddressSet private _curves;

    uint256 public protocolFeeBps;
    uint256 private constant BPS_PRECISION = 10_000;

    mapping(address curve => address token) public curveToToken;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
      address _curveImplementation,
      address _tokenImplementation,
      address _vestingImplementation,
      address _graduationManagerImplementation,
      address _protocolTreasury,
      uint256 _protocolFeeBps
    ) {
        if (
          _curveImplementation == address(0) ||
          _tokenImplementation == address(0) ||
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
        TOKEN_IMPLEMENTATION = _tokenImplementation;
        VESTING_IMPLEMENTATION = _vestingImplementation;
        GRADUATION_MANAGER_IMPLEMENTATION = _graduationManagerImplementation;

        protocolTreasury = _protocolTreasury;
        protocolFeeBps = _protocolFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                              CURVE CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ICurveFactory
    function createCurve(CreateCurveParams calldata config) external returns (address curve) {
        if (config.curveParams.collateralToken == address(0) || config.curveParams.segments.length == 0) {
            revert INVALID_CONFIG();
        }

        bytes32 salt = keccak256(abi.encode(msg.sender, config));

        // Clone all core contracts
        address curveInstance = CURVE_IMPLEMENTATION.cloneDeterministic(salt);
        address tokenInstance = TOKEN_IMPLEMENTATION.cloneDeterministic(salt);
        address graduationManagerInstance = GRADUATION_MANAGER_IMPLEMENTATION.cloneDeterministic(salt);

        // Clone vesting only if configured
        address vestingInstance;
        if (config.vestingConfig.cliffDuration > 0 && config.vestingConfig.vestingDuration > 0) {
            vestingInstance = VESTING_IMPLEMENTATION.cloneDeterministic(salt);
        }

        // Initialize the token (minter = curve)
        BondingToken(tokenInstance).initialize(config.name, config.symbol, config.decimals, curveInstance);

        // Initialize the curve
        Curve(curveInstance).initialize(
            tokenInstance, vestingInstance, graduationManagerInstance, protocolTreasury, protocolFeeBps, config
        );

        // Initialize the graduation manager
        GraduationManager(graduationManagerInstance).initialize(
            curveInstance,
            tokenInstance,
            config.curveParams.collateralToken
        );

        // Initialize vesting if deployed
        if (vestingInstance != address(0)) {
            Vesting(vestingInstance).initialize(
                tokenInstance,
                config.vestingConfig.cliffDuration,
                config.vestingConfig.vestingDuration
            );
        }

        // Register
        _curves.add(curveInstance);
        curveToToken[curveInstance] = tokenInstance;

        emit CurveCreated(curveInstance, tokenInstance, msg.sender);

        return curveInstance;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ICurveFactory
    function getCurveCount() external view returns (uint256) {
        return _curves.length();
    }

    /// @inheritdoc ICurveFactory
    function isCurve(address curve) external view returns (bool) {
        return _curves.contains(curve);
    }

    /// @inheritdoc ICurveFactory
    function getCurves() external view returns (address[] memory) {
        return _curves.values();
    }
}
