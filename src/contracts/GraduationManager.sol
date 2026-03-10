// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IGraduationManager } from "../interfaces/IGraduationManager.sol";

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract GraduationManager is Initializable, IGraduationManager {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public curve;
    address public token;
    address public collateralToken;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ONLY_CURVE();
    error INVALID_CURVE();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Initialized(address indexed curve, address indexed token, address indexed collateralToken);

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
    /// @notice Initializes the graduation manager for a specific bonding curve
    /// @dev Can only be called once. Called by the CurveFactory during curve creation.
    /// @param _curve The address of the bonding curve this manager serves
    /// @param _token The address of the bonding curve's ERC20 token
    /// @param _collateralToken The address of the collateral token used by the curve
    function initialize(address _curve, address _token, address _collateralToken) external initializer {
        if (_curve == address(0)) revert INVALID_CURVE();

        curve = _curve;
        token = _token;
        collateralToken = _collateralToken;

        emit Initialized(_curve, _token, _collateralToken);
    }

    /*//////////////////////////////////////////////////////////////
                              GRADUATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IGraduationManager
    function graduate(
        address _curve,
        address _collateral,
        uint256 tokenAmount,
        uint256 collateralAmount
    )
        external
        onlyCurve
    {
        // TODO: Implement DEX liquidity migration
    }
}
