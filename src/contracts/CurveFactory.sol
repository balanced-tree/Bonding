// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Contracts
import { Curve } from "./Curve.sol";
import { Vesting } from "./Vesting.sol";
import { BondingToken } from "./BondingToken.sol";
import { GraduationManager } from "./GraduationManager.sol";
import { ICurveFactory } from "../interfaces/ICurveFactory.sol";
import { CreateCurveParams, PiecewiseSegment } from "../Types.sol";

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
    uint256 private constant MAX_FEE_BPS = 3000; // 30% max combined fees
    uint256 private constant MAX_SEGMENTS = 3;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public immutable PROTOCOL_FEE_BPS;

    address public immutable PROTOCOL_TREASURY;
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
        uint256 _protocolFeeBps
    ) {
        if (
            _curveImplementation == address(0) || _tokenImplementation == address(0)
                || _vestingImplementation == address(0) || _graduationManagerImplementation == address(0)
                || _protocolTreasury == address(0)
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

        PROTOCOL_TREASURY = _protocolTreasury;
        PROTOCOL_FEE_BPS = _protocolFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                              CURVE CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ICurveFactory
    function createCurve(CreateCurveParams calldata config) external returns (address curve) {
        if (config.curveParams.collateralToken == address(0)) revert INVALID_CONFIG();
        _validateSegments(config.curveParams.segments);
        _validateFeeRecipient(config.feeRecipient, config.feeRecipientBps);

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
        Curve(curveInstance)
            .initialize(
                tokenInstance, vestingInstance, graduationManagerInstance, PROTOCOL_TREASURY, PROTOCOL_FEE_BPS, config
            );

        // Initialize the graduation manager
        GraduationManager(graduationManagerInstance)
            .initialize(curveInstance, tokenInstance, config.curveParams.collateralToken);

        // Initialize vesting if deployed
        if (vestingInstance != address(0)) {
            Vesting(vestingInstance)
                .initialize(
                    tokenInstance,
                    curveInstance,
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

    /// @dev Validates fee recipient configuration:
    ///      - If feeRecipient is set, feeRecipientBps must be > 0
    ///      - If feeRecipient is address(0), feeRecipientBps must be 0
    ///      - Combined fees (protocol + creator) must not exceed MAX_FEE_BPS (30%)
    function _validateFeeRecipient(address recipient, uint256 recipientBps) private view {
        if (recipient == address(0) && recipientBps > 0) revert INVALID_CONFIG();
        if (recipient != address(0) && recipientBps == 0) revert INVALID_CONFIG();
        if (PROTOCOL_FEE_BPS + recipientBps > MAX_FEE_BPS) revert INVALID_FEE_BPS();
    }
}
