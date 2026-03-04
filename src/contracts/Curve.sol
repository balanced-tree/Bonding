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
    address public vesting;
    address public treasury;

    uint256 public protocolFeeBps;

    bool public graduated;
    bool public initialized;
    
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {}

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address _token,
        address _vesting,
        address _treasury,
        uint256 _protocolFeeBps,
        CreateCurveParams memory params
    ) external initializer {
        if (initialized) revert ALREADY_INITIALIZED();
        initialized = true;

        token = _token;
        vesting = _vesting;
        treasury = _treasury;
        protocolFeeBps = _protocolFeeBps;
    }

}