// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Testing
import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { Curve } from "../src/contracts/Curve.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { ICurveFactory } from "../src/interfaces/ICurveFactory.sol";
import { GraduationManager } from "../src/contracts/GraduationManager.sol";

contract CurveTest is BaseTest, Helpers {
    Curve public curve;
    Vesting public vesting;
    BondingToken public token;
    GraduationManager public graduationManager;
    
    function setUp() public override {
        super.setUp();

        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(50_000e18);

        (address _curve, address _token, address _vesting, address _gm) =
            curveFactory.createCurve(
                Types.CreateCurveParams({
                    name: "Bonding Curve",
                    symbol: "BOND",
                    decimals: 18,
                    feeRecipient: feeRecipient,
                    feeRecipientBps: protocolFeeBps,
                    curveParams: Types.CurveParams({
                        collateralToken: address(usdc),
                        segments: segs,
                        maxThreshold: 1e18,
                        maxBuyPerTx: 10_000,
                        maxSellPerTx: 10_000
                    }),
                    vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
                })
            );

        vm.stopPrank();

        curve = Curve(_curve);
        token = BondingToken(_token);
        vesting = Vesting(_vesting);
        graduationManager = GraduationManager(_gm);
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_initialize() public view {
        // Token & collateral addresses
        assertEq(curve.token(), address(token));
        assertEq(curve.getTokenAddress(), address(token));
        assertEq(curve.collateralToken(), address(usdc));
        assertEq(curve.getCollateralAddress(), address(usdc));

        // Protocol addresses
        assertEq(curve.treasury(), protocolTreasury);
        assertEq(curve.graduationManager(), address(graduationManager));

        // No vesting configured (both cliff and duration are 0)
        assertEq(curve.vesting(), address(0));

        // Fee configuration
        assertEq(curve.protocolFeeBps(), protocolFeeBps);
        assertEq(curve.feeRecipient(), feeRecipient);
        assertEq(curve.feeRecipientBps(), protocolFeeBps);

        // Curve parameters
        assertEq(curve.maxThreshold(), 1e18);
        assertEq(curve.maxBuyPerTx(), 10_000);
        assertEq(curve.maxSellPerTx(), 10_000);

        // Not graduated
        assertFalse(curve.graduated());

        // Two segments stored (LINEAR + PARABOLIC)
        (uint256 s0Start, uint256 s0End, Types.FormulaType s0Type,) = curve.segments(0);
        assertEq(s0Start, 0);
        assertEq(s0End, 50_000e18);
        assertEq(uint8(s0Type), uint8(Types.FormulaType.LINEAR));

        (uint256 s1Start, uint256 s1End, Types.FormulaType s1Type,) = curve.segments(1);
        assertEq(s1Start, 50_000e18);
        assertEq(s1End, 100_000e18);
        assertEq(uint8(s1Type), uint8(Types.FormulaType.PARABOLIC));

        // Initial supply is 0 so spot price should reflect supply=0 on the linear segment
        // With default linear params (m=1, b=0): p(0) = 0
        assertEq(curve.getPrice(), 0);

        // Token metadata
        assertEq(token.name(), "Bonding Curve");
        assertEq(token.symbol(), "BOND");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          GETTER: getTokenAddress
    //////////////////////////////////////////////////////////////*/

    function test_getTokenAddress() public view {
        assertEq(curve.getTokenAddress(), address(token));
        assertEq(curve.getTokenAddress(), curve.token());
    }

    /*//////////////////////////////////////////////////////////////
                        GETTER: getCollateralAddress
    //////////////////////////////////////////////////////////////*/

    function test_getCollateralAddress() public view {
        assertEq(curve.getCollateralAddress(), address(usdc));
        assertEq(curve.getCollateralAddress(), curve.collateralToken());
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER: getPrice
    //////////////////////////////////////////////////////////////*/

    function test_getPrice_atZeroSupply() public view {
        // LINEAR segment: p(s) = m*s + b = 1*0 + 0 = 0
        assertEq(curve.getPrice(), 0);
    }

    function test_getPrice_afterSupplyIncrease_linearSegment() public {
        // Mint tokens to simulate supply increase (minter = curve)
        uint256 mintAmount = 100e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        // LINEAR segment: p(s) = 1*s + 0 = s
        // At supply = 100e18, price should be 100e18
        assertEq(curve.getPrice(), mintAmount);
    }

    function test_getPrice_atSegmentBoundary() public {
        // Mint exactly to the boundary between LINEAR and PARABOLIC (50_000e18)
        uint256 boundary = 50_000e18;
        vm.prank(address(curve));
        token.mint(alice, boundary);

        // At supply = 50_000e18, we're at the start of the PARABOLIC segment
        uint256 price = curve.getPrice();
        assertGt(price, 0);
    }

    function test_getPrice_inParabolicSegment() public {
        // Mint past the boundary into the parabolic segment
        uint256 supply = 60_000e18;
        vm.prank(address(curve));
        token.mint(alice, supply);

        // PARABOLIC: p(s) = s² (a=1, b=0, c=0)
        // Price should be much larger than at the boundary
        uint256 price = curve.getPrice();
        assertGt(price, 0);

        // Price in parabolic segment should be greater than linear would give
        // Linear would give p = 60_000e18, but parabolic gives p = (60_000e18)²/1e18
        assertGt(price, 60_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                          GETTER: getBuyQuote
    //////////////////////////////////////////////////////////////*/

    function test_getBuyQuote_returnsNonZeroForNonZeroInput() public view {
        uint256 tokensOut = curve.getBuyQuote(1000e6);
        assertGt(tokensOut, 0);
    }

    function test_getBuyQuote_moreCollateralGivesMoreTokens() public view {
        uint256 tokensSmall = curve.getBuyQuote(100e6);
        uint256 tokensLarge = curve.getBuyQuote(1000e6);
        assertGt(tokensLarge, tokensSmall);
    }

    function test_getBuyQuote_accountsForFees() public view {
        // With 20% total fees (10% protocol + 10% creator), only 80% of collateral is priced
        // Verify diminishing returns on the curve (not linear relationship)
        uint256 collateral = 1000e6;
        uint256 quotedTokens = curve.getBuyQuote(collateral);

        uint256 quotedTokensFull = curve.getBuyQuote(collateral * 5);
        // 5x collateral doesn't give 5x tokens on a curve (diminishing returns)
        assertGt(quotedTokensFull, quotedTokens);
        assertLt(quotedTokensFull, quotedTokens * 5);
    }

    function test_getBuyQuote_afterSupplyIncrease() public {
        // Mint some supply first — prices are higher so same collateral buys fewer tokens
        uint256 quoteBefore = curve.getBuyQuote(1000e6);

        vm.prank(address(curve));
        token.mint(alice, 1000e18);

        uint256 quoteAfter = curve.getBuyQuote(1000e6);

        // Higher supply = higher price = fewer tokens for same collateral
        assertLt(quoteAfter, quoteBefore);
    }

    function test_getBuyQuote_matchesActualBuy() public {
        uint256 collateral = 100e6; // 100 USDC

        // Get the quote first
        uint256 expectedTokens = curve.getBuyQuote(collateral);

        // Perform the actual buy
        vm.startPrank(alice);
        usdc.approve(address(curve), collateral);
        uint256 actualTokens = curve.buy(collateral, 0);
        vm.stopPrank();

        // Quote and actual should match exactly
        assertEq(actualTokens, expectedTokens);
    }

    
}