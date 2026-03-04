// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { 
    CurveParams,
    VestingConfig,
    PiecewiseSegment, 
    CreateCurveParams
} from "../Types.sol";
import { ICurve } from "../interfaces/ICurve.sol";
import { IVesting } from "../interfaces/IVesting.sol";

// OpenZeppelin Contracts
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

// OpenZeppelin Upgradeable
import { ERC20Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract Curve is Initializable, ICurve, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public token;
    address public collateralToken;

    address public vesting;
    address public treasury;

    uint256 public maxBuyPerTx;
    uint256 public maxSellPerTx;
    uint256 public maxThreshold;
    uint256 public protocolFeeBps;

    bool public graduated;

    PiecewiseSegment[] public segments;
    
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {}

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the curve contract
    /// @dev This function can only be called once due to initializer modifier
    /// @dev Security: addresses are already validated in the factory
    /// @param _token The address of the token contract
    /// @param _vesting The address of the vesting contract
    /// @param _treasury The address of the treasury
    /// @param _protocolFeeBps The protocol fee in basis points
    /// @param params The parameters for the curve
    function initialize(
        address _token,
        address _vesting,
        address _treasury,
        uint256 _protocolFeeBps,
        CreateCurveParams memory params
    ) external initializer {
        // Initialize state variables
        token = _token;
        vesting = _vesting;
        treasury = _treasury;
        protocolFeeBps = _protocolFeeBps;

        segments = params.curveParams.segments;
        maxBuyPerTx = params.curveParams.maxBuyPerTx;
        maxSellPerTx = params.curveParams.maxSellPerTx;
        maxThreshold = params.curveParams.maxThreshold;
        collateralToken = params.curveParams.collateralToken;

        emit Initialized(token, vesting, protocolFeeBps);
    }

}