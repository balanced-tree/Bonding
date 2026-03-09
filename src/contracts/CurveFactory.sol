// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { CreateCurveParams, PiecewiseSegment } from "../Types.sol";
import { Curve } from "./Curve.sol";
import { Vesting } from "./Vesting.sol";
import { BondingToken } from "./BondingToken.sol";
import { GraduationManager } from "./GraduationManager.sol";
import { ICurveFactory } from "../interfaces/ICurveFactory.sol";

// OpenZeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title CurveFactory
/// @notice Factory for deploying and registering bonding curve clones
/// @author balanced-tree
contract CurveFactory is ICurveFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant BPS_PRECISION = 10_000;
    uint256 private constant MAX_SEGMENTS = 3;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable PROTOCOL_TREASURY;
    uint256 public immutable PROTOCOL_FEE_BPS;

    address public immutable CURVE_IMPLEMENTATION;
    address public immutable TOKEN_IMPLEMENTATION;
    address public immutable VESTING_IMPLEMENTATION;
    address public immutable GRADUATION_MANAGER_IMPLEMENTATION;

    EnumerableSet.AddressSet private _curves;

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
        uint256 _PROTOCOL_FEE_BPS
    ) {
        if (
            _curveImplementation == address(0) || _tokenImplementation == address(0)
                || _vestingImplementation == address(0) || _graduationManagerImplementation == address(0)
                || _protocolTreasury == address(0)
        ) {
            revert INVALID_ADDRESS();
        }

        if (_PROTOCOL_FEE_BPS >= BPS_PRECISION || _PROTOCOL_FEE_BPS == 0) {
            revert INVALID_FEE_BPS();
        }

        CURVE_IMPLEMENTATION = _curveImplementation;
        TOKEN_IMPLEMENTATION = _tokenImplementation;
        VESTING_IMPLEMENTATION = _vestingImplementation;
        GRADUATION_MANAGER_IMPLEMENTATION = _graduationManagerImplementation;

        PROTOCOL_TREASURY = _protocolTreasury;
        PROTOCOL_FEE_BPS = _PROTOCOL_FEE_BPS;
    }

    /*//////////////////////////////////////////////////////////////
                              CURVE CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ICurveFactory
    function createCurve(CreateCurveParams calldata config) external returns (address curve) {
        if (config.curveParams.collateralToken == address(0)) revert INVALID_CONFIG();
        _validateSegments(config.curveParams.segments);

        // forge-lint: disable-next-line(asm-keccak256)
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
            tokenInstance, vestingInstance, graduationManagerInstance, PROTOCOL_TREASURY, PROTOCOL_FEE_BPS, config
        );

        // Initialize the graduation manager
        GraduationManager(graduationManagerInstance).initialize(
            curveInstance, tokenInstance, config.curveParams.collateralToken
        );

        // Initialize vesting if deployed
        if (vestingInstance != address(0)) {
            Vesting(vestingInstance).initialize(
                tokenInstance, config.vestingConfig.cliffDuration, config.vestingConfig.vestingDuration
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

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Validates piecewise segment configuration:
    ///      - 1 to MAX_SEGMENTS segments
    ///      - First segment starts at 0
    ///      - Segments are contiguous (no gaps or overlaps)
    ///      - Each segment has supplyStart < supplyEnd
    function _validateSegments(PiecewiseSegment[] calldata segs) private pure {
        uint256 len = segs.length;
        if (len == 0 || len > MAX_SEGMENTS) revert INVALID_SEGMENTS();

        // First segment must start at supply 0
        if (segs[0].supplyStart != 0) revert INVALID_SEGMENTS();

        for (uint256 i; i < len; ++i) {
            // Each segment must have a valid range
            if (segs[i].supplyStart >= segs[i].supplyEnd) revert INVALID_SEGMENTS();

            // Segments must be contiguous: next segment starts where previous ends
            if (i > 0 && segs[i].supplyStart != segs[i - 1].supplyEnd) {
                revert INVALID_SEGMENTS();
            }
        }
    }
}
