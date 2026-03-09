// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Contracts
import { ICurve } from "../interfaces/ICurve.sol";
import { BondingToken } from "./BondingToken.sol";
import { PriceLib } from "../libraries/PriceLib.sol";
import { IVesting } from "../interfaces/IVesting.sol";
import { PiecewiseSegment, CreateCurveParams } from "../Types.sol";
import { IGraduationManager } from "../interfaces/IGraduationManager.sol";

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

// OpenZeppelin Upgradeable
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract Curve is Initializable, ICurve, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant BPS_PRECISION = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public token;
    address public collateralToken;

    address public vesting;
    address public treasury;
    address public graduationManager;
    address public feeRecipient;

    uint256 public maxBuyPerTx;
    uint256 public maxSellPerTx;
    uint256 public maxThreshold;
    uint256 public protocolFeeBps;
    uint256 public feeRecipientBps;

    bool public graduated;

    PiecewiseSegment[] public segments;

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
    /// @notice Initializes the curve contract
    /// @dev This function can only be called once due to initializer modifier.
    ///      Security: addresses are already validated in the factory.
    /// @param _token The address of the token contract
    /// @param _vesting The address of the vesting contract (address(0) if none)
    /// @param _graduationManager The address of the graduation manager
    /// @param _treasury The address of the treasury
    /// @param _protocolFeeBps The protocol fee in basis points
    /// @param params The parameters for the curve
    function initialize(
        address _token,
        address _vesting,
        address _graduationManager,
        address _treasury,
        uint256 _protocolFeeBps,
        CreateCurveParams memory params
    ) external initializer {
        token = _token;
        if (_vesting != address(0)) vesting = _vesting;
        graduationManager = _graduationManager;
        treasury = _treasury;
        protocolFeeBps = _protocolFeeBps;
        collateralToken = params.curveParams.collateralToken;
        maxBuyPerTx = params.curveParams.maxBuyPerTx;
        maxSellPerTx = params.curveParams.maxSellPerTx;
        maxThreshold = params.curveParams.maxThreshold;

        if (params.feeRecipient != address(0)) {
            feeRecipient = params.feeRecipient;
            feeRecipientBps = params.feeRecipientBps;
        }

        // Copy segments to storage (must be done element-by-element for dynamic bytes)
        for (uint256 i; i < params.curveParams.segments.length; ++i) {
            segments.push(params.curveParams.segments[i]);
        }

        emit Initialized(token, vesting, protocolFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICurve
    function buy(uint256 collateralAmount, uint256 minTokensOut) external nonReentrant returns (uint256 tokensOut) {
        if (collateralAmount == 0) revert INVALID_AMOUNT();
        if (graduated) revert ALREADY_GRADUATED();

        // Calculate fees and net collateral for pricing
        (uint256 protocolFee, uint256 creatorFee) = _calculateFees(collateralAmount);
        uint256 totalFee = protocolFee + creatorFee;
        uint256 netCollateral = collateralAmount - totalFee;

        // Calculate tokens to mint from net collateral
        uint256 currentSupply = BondingToken(token).totalSupply();
        tokensOut = PriceLib.calculateBuyTokens(_getSegments(), currentSupply, netCollateral);

        // Check slippage and per-tx limits
        if (tokensOut < minTokensOut) revert SLIPPAGE_EXCEEDED();
        if (maxBuyPerTx > 0 && tokensOut > maxBuyPerTx) revert EXCEEDS_MAX_PER_TX();

        // Interactions: transfer collateral in, mint tokens out
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), netCollateral);
        IERC20(collateralToken).safeTransferFrom(msg.sender, treasury, protocolFee);
        if (creatorFee > 0) {
            IERC20(collateralToken).safeTransferFrom(msg.sender, feeRecipient, creatorFee);
        }

        if (vesting != address(0)) {
            BondingToken(token).mint(vesting, tokensOut);
            IVesting(vesting).addVesting(msg.sender, tokensOut);
        } else {
            BondingToken(token).mint(msg.sender, tokensOut);
        }

        emit TokensBought(msg.sender, collateralAmount, tokensOut, totalFee);

        // Check graduation threshold
        _checkGraduation();
    }

    /// @inheritdoc ICurve
    function sell(uint256 tokenAmount, uint256 minCollateralOut) external nonReentrant returns (uint256 collateralOut) {
        if (tokenAmount == 0) revert INVALID_AMOUNT();
        if (graduated) revert ALREADY_GRADUATED();
        if (maxSellPerTx > 0 && tokenAmount > maxSellPerTx) revert EXCEEDS_MAX_PER_TX();

        // Calculate collateral to return
        uint256 currentSupply = BondingToken(token).totalSupply();
        uint256 grossCollateral = PriceLib.calculateSellCollateral(_getSegments(), currentSupply, tokenAmount);

        // Deduct fee
        uint256 fee = (grossCollateral * protocolFeeBps) / BPS_PRECISION;
        collateralOut = grossCollateral - fee;

        if (collateralOut == 0) revert ZERO_COLLATERAL_OUT();
        if (collateralOut < minCollateralOut) revert SLIPPAGE_EXCEEDED();

        // Effects: burn tokens first (CEI pattern)
        BondingToken(token).burn(msg.sender, tokenAmount);

        // Interactions: transfer collateral out
        IERC20(collateralToken).safeTransfer(treasury, fee);
        IERC20(collateralToken).safeTransfer(msg.sender, collateralOut);

        emit TokensSold(msg.sender, tokenAmount, collateralOut, fee);
    }

    /// @inheritdoc ICurve
    function graduateCurve() external nonReentrant {
        if (graduated) revert ALREADY_GRADUATED();
        uint256 collateralBalance = IERC20(collateralToken).balanceOf(address(this));
        if (maxThreshold == 0 || collateralBalance < maxThreshold) revert INVALID_CONFIGURATION();

        graduated = true;

        uint256 tokenSupply = BondingToken(token).totalSupply();

        // Approve graduation manager to pull collateral
        IERC20(collateralToken).safeIncreaseAllowance(graduationManager, collateralBalance);

        IGraduationManager(graduationManager).graduate(
            address(this), collateralToken, tokenSupply, collateralBalance
        );

        emit CurveGraduated(collateralBalance, tokenSupply);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICurve
    function getPrice() external view returns (uint256) {
        uint256 currentSupply = BondingToken(token).totalSupply();
        return PriceLib.getSpotPrice(_getSegments(), currentSupply);
    }

    /// @inheritdoc ICurve
    function getTokenAddress() external view returns (address) {
        return token;
    }

    /// @inheritdoc ICurve
    function getCollateralAddress() external view returns (address) {
        return collateralToken;
    }

    /// @inheritdoc ICurve
    function getBuyQuote(uint256 collateralAmount) external view returns (uint256 tokensOut) {
        uint256 fee = (collateralAmount * protocolFeeBps) / BPS_PRECISION;
        uint256 netCollateral = collateralAmount - fee;
        uint256 currentSupply = BondingToken(token).totalSupply();
        tokensOut = PriceLib.calculateBuyTokens(_getSegments(), currentSupply, netCollateral);
    }

    /// @inheritdoc ICurve
    function getSellQuote(uint256 tokenAmount) external view returns (uint256 collateralOut) {
        uint256 currentSupply = BondingToken(token).totalSupply();
        uint256 grossCollateral = PriceLib.calculateSellCollateral(_getSegments(), currentSupply, tokenAmount);
        uint256 fee = (grossCollateral * protocolFeeBps) / BPS_PRECISION;
        collateralOut = grossCollateral - fee;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks if the graduation threshold has been met and triggers graduation if so
    function _checkGraduation() internal {
        if (maxThreshold == 0) return;
        uint256 collateralBalance = IERC20(collateralToken).balanceOf(address(this));
        if (collateralBalance < maxThreshold) return;

        graduated = true;

        uint256 tokenSupply = BondingToken(token).totalSupply();

        IERC20(collateralToken).safeIncreaseAllowance(graduationManager, collateralBalance);

        IGraduationManager(graduationManager).graduate(
            address(this), collateralToken, tokenSupply, collateralBalance
        );

        emit CurveGraduated(collateralBalance, tokenSupply);
    }

    /// @dev Copies storage segments into memory for PriceLib consumption
    function _getSegments() internal view returns (PiecewiseSegment[] memory) {
        return segments;
    }
}
