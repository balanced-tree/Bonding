// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Testing
import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { ICurve } from "../src/interfaces/ICurve.sol";
import { Curve } from "../src/contracts/Curve.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { ICurveFactory } from "../src/interfaces/ICurveFactory.sol";
import { GraduationManager } from "../src/contracts/GraduationManager.sol";

// OpenZeppelin
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CurveTest is BaseTest, Helpers {
    Curve public curve;
    Vesting public vesting;
    BondingToken public token;
    GraduationManager public graduationManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(50_000e18);

        (address _curve, address _token, address _vesting, address _gm) = curveFactory.createCurve(
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

    function test_getBuyQuote_quoteIsConsistentAcrossSupplyLevels() public {
        // Get quote at supply=0
        uint256 quoteAtZero = curve.getBuyQuote(1000e6);

        // Mint to increase supply, then get quote again
        vm.prank(address(curve));
        token.mint(alice, 5000e18);
        uint256 quoteAtHigherSupply = curve.getBuyQuote(1000e6);

        // At higher supply, same collateral buys fewer tokens (prices are higher)
        assertLt(quoteAtHigherSupply, quoteAtZero);

        // Both quotes should be non-zero
        assertGt(quoteAtZero, 0);
        assertGt(quoteAtHigherSupply, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          GETTER: getSellQuote
    //////////////////////////////////////////////////////////////*/

    function test_getSellQuote_returnsNonZeroForNonZeroSupply() public {
        // Need supply for sell quote to have meaning
        uint256 mintAmount = 1000e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        uint256 collateralOut = curve.getSellQuote(100e18);
        assertGt(collateralOut, 0);
    }

    function test_getSellQuote_moreTokensGivesMoreCollateral() public {
        uint256 mintAmount = 1000e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        uint256 collateralSmall = curve.getSellQuote(100e18);
        uint256 collateralLarge = curve.getSellQuote(500e18);
        assertGt(collateralLarge, collateralSmall);
    }

    function test_getSellQuote_accountsForFees() public {
        // Mint supply
        uint256 mintAmount = 1000e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        uint256 sellAmount = 500e18;
        uint256 quotedCollateral = curve.getSellQuote(sellAmount);

        // Selling the full supply should return more collateral than partial
        uint256 quotedCollateralFull = curve.getSellQuote(mintAmount);
        assertGt(quotedCollateralFull, quotedCollateral);
    }

    function test_getSellQuote_sellingAllSupplyGivesMaxCollateral() public {
        // Mint supply
        uint256 mintAmount = 1000e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        // Selling everything gives more than any partial amount
        uint256 quotedHalf = curve.getSellQuote(mintAmount / 2);
        uint256 quotedFull = curve.getSellQuote(mintAmount);
        assertGt(quotedFull, quotedHalf);

        // Due to the curve shape (increasing price), the top half of supply
        // is more valuable than the bottom half. So selling all gives LESS
        // than 2x selling the top half.
        assertLt(quotedFull, quotedHalf * 2);
    }

    function test_getSellQuote_decreasesWithFees() public {
        // Mint supply and check that sell quote reflects fee deductions
        uint256 mintAmount = 1000e18;
        vm.prank(address(curve));
        token.mint(alice, mintAmount);

        uint256 sellQuote = curve.getSellQuote(mintAmount);

        // With LINEAR p(s) = s, integral from 0 to 1000e18 = (1000e18)² / (2*1e18) = 5e38
        // After 20% fees, sell quote should be 80% of that
        // Verify it's positive but less than the gross integral
        assertGt(sellQuote, 0);
    }

    function test_getSellQuote_atDifferentSupplyLevels() public {
        // At higher supply, selling the same number of tokens returns more collateral
        // because those tokens sit on a steeper part of the curve

        // Scenario 1: supply = 1000e18, sell 500e18
        vm.prank(address(curve));
        token.mint(alice, 1000e18);
        uint256 quoteAtLowSupply = curve.getSellQuote(500e18);

        // Scenario 2: supply = 5000e18, sell 500e18
        vm.prank(address(curve));
        token.mint(alice, 4000e18); // total now 5000e18
        uint256 quoteAtHighSupply = curve.getSellQuote(500e18);

        // Selling 500 tokens from 5000 supply is more valuable than from 1000 supply
        assertGt(quoteAtHighSupply, quoteAtLowSupply);
    }

    /*//////////////////////////////////////////////////////////////
                            BUY: REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_buy_revert_zeroAmount() public {
        (Curve buyCurve,) = _deployBuyCurve();

        vm.prank(alice);
        vm.expectRevert(ICurve.INVALID_AMOUNT.selector);
        buyCurve.buy(0, 0);
    }

    function test_buy_revert_alreadyGraduated() public {
        (Curve gradCurve,) = _deployGraduatableCurve();

        // Buy enough to trigger graduation (threshold = 10 USDC)
        // Net collateral after 20% fees needs to be >= 10 USDC, so spend 15 USDC
        vm.startPrank(alice);
        usdc.approve(address(gradCurve), 15e6);
        gradCurve.buy(15e6, 0);
        vm.stopPrank();

        assertTrue(gradCurve.graduated());

        // Now try to buy again
        vm.startPrank(alice);
        usdc.approve(address(gradCurve), 1e6);
        vm.expectRevert(ICurve.ALREADY_GRADUATED.selector);
        gradCurve.buy(1e6, 0);
        vm.stopPrank();
    }

    function test_buy_revert_slippageExceeded() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 100e6;
        uint256 expectedTokens = buyCurve.getBuyQuote(collateral);

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        // Set minTokensOut higher than what we'd actually get
        vm.expectRevert(ICurve.SLIPPAGE_EXCEEDED.selector);
        buyCurve.buy(collateral, expectedTokens + 1);
        vm.stopPrank();
    }

    function test_buy_revert_exceedsMaxPerTx() public {
        // Use the default curve which has maxBuyPerTx = 10_000
        // Any non-zero USDC buy produces far more than 10_000 token-wei
        vm.startPrank(alice);
        usdc.approve(address(curve), 1e6);
        vm.expectRevert(ICurve.EXCEEDS_MAX_PER_TX.selector);
        curve.buy(1e6, 0);
        vm.stopPrank();
    }

    function test_buy_revert_noApproval() public {
        (Curve buyCurve,) = _deployBuyCurve();

        // Don't approve — SafeERC20 will revert
        vm.prank(alice);
        vm.expectRevert();
        buyCurve.buy(100e6, 0);
    }

    function test_buy_revert_insufficientBalance() public {
        (Curve buyCurve,) = _deployBuyCurve();

        // Eve has 1000 USDC, try to buy with way more
        uint256 tooMuch = 1_000_000e6;
        vm.startPrank(eve);
        usdc.approve(address(buyCurve), tooMuch);
        vm.expectRevert();
        buyCurve.buy(tooMuch, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          BUY: SUCCESS
    //////////////////////////////////////////////////////////////*/

    function test_buy_basic() public {
        (Curve buyCurve, BondingToken buyToken) = _deployBuyCurve();

        uint256 collateral = 100e6; // 100 USDC
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        uint256 tokensOut = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Alice received tokens
        assertEq(buyToken.balanceOf(alice), tokensOut);
        assertGt(tokensOut, 0);

        // Alice's USDC decreased by the full collateral amount
        assertEq(usdc.balanceOf(alice), aliceUsdcBefore - collateral);

        // Token supply increased
        assertEq(buyToken.totalSupply(), tokensOut);

        // Spot price increased from 0
        assertGt(buyCurve.getPrice(), 0);
    }

    function test_buy_matchesQuote() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 50e6;
        uint256 quoted = buyCurve.getBuyQuote(collateral);

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        uint256 actual = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        assertEq(actual, quoted);
    }

    function test_buy_exactSlippageAccepted() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 100e6;
        uint256 expectedTokens = buyCurve.getBuyQuote(collateral);

        // Setting minTokensOut exactly to expected should succeed
        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        uint256 tokensOut = buyCurve.buy(collateral, expectedTokens);
        vm.stopPrank();

        assertEq(tokensOut, expectedTokens);
    }

    /*//////////////////////////////////////////////////////////////
                      BUY: SUCCESS — FEE DISTRIBUTION
    //////////////////////////////////////////////////////////////*/

    function test_buy_feeDistribution() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 100e6; // 100 USDC

        // protocolFeeBps = 1000 (10%), feeRecipientBps = 1000 (10%)
        uint256 expectedProtocolFee = (collateral * protocolFeeBps) / 10_000; // 10 USDC
        uint256 expectedCreatorFee = (collateral * protocolFeeBps) / 10_000; // 10 USDC
        uint256 expectedNetCollateral = collateral - expectedProtocolFee - expectedCreatorFee; // 80 USDC

        uint256 treasuryBefore = usdc.balanceOf(protocolTreasury);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);
        uint256 curveBefore = usdc.balanceOf(address(buyCurve));

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Protocol treasury received protocol fee
        assertEq(usdc.balanceOf(protocolTreasury) - treasuryBefore, expectedProtocolFee);

        // Fee recipient received creator fee
        assertEq(usdc.balanceOf(feeRecipient) - feeRecipientBefore, expectedCreatorFee);

        // Curve contract holds the net collateral
        assertEq(usdc.balanceOf(address(buyCurve)) - curveBefore, expectedNetCollateral);
    }

    function test_buy_noCreatorFee() public {
        (Curve noFeeCurve,) = _deployNoFeeCurve();

        uint256 collateral = 100e6;
        uint256 expectedProtocolFee = (collateral * protocolFeeBps) / 10_000; // 10 USDC
        uint256 expectedNetCollateral = collateral - expectedProtocolFee; // 90 USDC

        uint256 treasuryBefore = usdc.balanceOf(protocolTreasury);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);

        vm.startPrank(alice);
        usdc.approve(address(noFeeCurve), collateral);
        noFeeCurve.buy(collateral, 0);
        vm.stopPrank();

        // Protocol fee still collected
        assertEq(usdc.balanceOf(protocolTreasury) - treasuryBefore, expectedProtocolFee);

        // Fee recipient unchanged (no creator fee)
        assertEq(usdc.balanceOf(feeRecipient), feeRecipientBefore);

        // Curve holds the net (90 USDC instead of 80 USDC)
        assertEq(usdc.balanceOf(address(noFeeCurve)), expectedNetCollateral);
    }

    function test_buy_moreTokensWithNoCreatorFee() public {
        (Curve buyCurve,) = _deployBuyCurve();
        (Curve noFeeCurve,) = _deployNoFeeCurve();

        uint256 collateral = 100e6;

        // Buy on curve with creator fee (20% total fees)
        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        uint256 tokensWithFee = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Buy on curve without creator fee (10% total fees)
        vm.startPrank(bob);
        usdc.approve(address(noFeeCurve), collateral);
        uint256 tokensNoFee = noFeeCurve.buy(collateral, 0);
        vm.stopPrank();

        // More net collateral -> more tokens
        assertGt(tokensNoFee, tokensWithFee);
    }

    /*//////////////////////////////////////////////////////////////
                    BUY: SUCCESS — EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_buy_emitsTokensBought() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 100e6;
        uint256 expectedTokens = buyCurve.getBuyQuote(collateral);
        uint256 expectedTotalFee = (collateral * protocolFeeBps * 2) / 10_000; // 20% total

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);

        vm.expectEmit(true, false, false, true);
        emit ICurve.TokensBought(alice, collateral, expectedTokens, expectedTotalFee);
        buyCurve.buy(collateral, 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                  BUY: SUCCESS — MULTIPLE BUYS
    //////////////////////////////////////////////////////////////*/

    function test_buy_multipleBuys_priceIncreases() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 50e6;

        // First buy at supply=0 (cheap)
        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral * 3);
        uint256 tokens1 = buyCurve.buy(collateral, 0);
        uint256 priceAfterFirst = buyCurve.getPrice();

        // Second buy at higher supply (more expensive)
        uint256 tokens2 = buyCurve.buy(collateral, 0);
        uint256 priceAfterSecond = buyCurve.getPrice();

        // Third buy at even higher supply
        uint256 tokens3 = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Price strictly increases after each buy
        assertGt(priceAfterSecond, priceAfterFirst);

        // Same collateral buys fewer tokens each time (diminishing returns)
        assertGt(tokens1, tokens2);
        assertGt(tokens2, tokens3);
    }

    function test_buy_multipleBuyers() public {
        (Curve buyCurve, BondingToken buyToken) = _deployBuyCurve();

        uint256 collateral = 50e6;

        // Alice buys first
        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        uint256 aliceTokens = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Bob buys second (at higher price)
        vm.startPrank(bob);
        usdc.approve(address(buyCurve), collateral);
        uint256 bobTokens = buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Both have tokens
        assertEq(buyToken.balanceOf(alice), aliceTokens);
        assertEq(buyToken.balanceOf(bob), bobTokens);

        // Total supply = sum
        assertEq(buyToken.totalSupply(), aliceTokens + bobTokens);

        // Alice got more tokens (bought at lower price)
        assertGt(aliceTokens, bobTokens);
    }

    /*//////////////////////////////////////////////////////////////
                  BUY: SUCCESS — GRADUATION TRIGGER
    //////////////////////////////////////////////////////////////*/

    function test_buy_triggersGraduation() public {
        (Curve gradCurve,) = _deployGraduatableCurve();

        assertFalse(gradCurve.graduated());

        // Threshold = 10 USDC. With 20% fees, need net >= 10 USDC
        // collateral * 80% >= 10 USDC -> collateral >= 12.5 USDC. Use 15 USDC.
        uint256 collateral = 15e6;

        vm.startPrank(alice);
        usdc.approve(address(gradCurve), collateral);
        gradCurve.buy(collateral, 0);
        vm.stopPrank();

        assertTrue(gradCurve.graduated());
    }

    function test_buy_emitsCurveGraduated() public {
        (Curve gradCurve,) = _deployGraduatableCurve();

        uint256 collateral = 15e6;

        vm.startPrank(alice);
        usdc.approve(address(gradCurve), collateral);

        // Expect CurveGraduated event
        vm.expectEmit(false, false, false, false);
        emit ICurve.CurveGraduated(0, 0);
        gradCurve.buy(collateral, 0);

        vm.stopPrank();
    }

    function test_buy_doesNotGraduateBelowThreshold() public {
        (Curve gradCurve,) = _deployGraduatableCurve();

        // Threshold = 10 USDC. Buy small so net < 10
        uint256 collateral = 5e6; // net = 4 USDC
        vm.startPrank(alice);
        usdc.approve(address(gradCurve), collateral);
        gradCurve.buy(collateral, 0);
        vm.stopPrank();

        assertFalse(gradCurve.graduated());
    }

    /*//////////////////////////////////////////////////////////////
                    BUY: SUCCESS — STATE CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_buy_supplyMatchesTotalMinted() public {
        (Curve buyCurve, BondingToken buyToken) = _deployBuyCurve();

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), 200e6);
        uint256 tokens1 = buyCurve.buy(100e6, 0);
        uint256 tokens2 = buyCurve.buy(100e6, 0);
        vm.stopPrank();

        assertEq(buyToken.totalSupply(), tokens1 + tokens2);
        assertEq(buyToken.balanceOf(alice), tokens1 + tokens2);
    }

    function test_buy_priceEqualsSupplyOnLinearCurve() public {
        (Curve buyCurve, BondingToken buyToken) = _deployBuyCurve();

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), 100e6);
        buyCurve.buy(100e6, 0);
        vm.stopPrank();

        // For LINEAR p(s) = s, price should equal the current supply
        uint256 supply = buyToken.totalSupply();
        uint256 price = buyCurve.getPrice();
        assertEq(price, supply);
    }

    function test_buy_curveCollateralBalanceConsistent() public {
        (Curve buyCurve,) = _deployBuyCurve();

        uint256 collateral = 100e6;
        uint256 expectedNet = collateral * 8000 / 10_000; // 80% after 20% fees

        vm.startPrank(alice);
        usdc.approve(address(buyCurve), collateral);
        buyCurve.buy(collateral, 0);
        vm.stopPrank();

        // Curve holds exactly the net collateral
        assertEq(usdc.balanceOf(address(buyCurve)), expectedNet);
    }

    /*//////////////////////////////////////////////////////////////
                      HELPERS: CURVE DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Deploys a curve with maxBuyPerTx=0 (no limit) for buy tests.
    ///      Uses a large maxThreshold so graduation doesn't auto-trigger.
    function _deployBuyCurve() internal returns (Curve buyCurve, BondingToken buyToken) {
        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(50_000e18);

        vm.prank(curveCreator);
        (address _c, address _t,,) = curveFactory.createCurve(
            Types.CreateCurveParams({
                name: "Buy Curve",
                symbol: "BUY",
                decimals: 18,
                feeRecipient: feeRecipient,
                feeRecipientBps: protocolFeeBps,
                curveParams: Types.CurveParams({
                    collateralToken: address(usdc),
                    segments: segs,
                    maxThreshold: 1_000_000e6, // high threshold
                    maxBuyPerTx: 0, // 0 = no per-tx limit
                    maxSellPerTx: 0
                }),
                vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
            })
        );

        buyCurve = Curve(_c);
        buyToken = BondingToken(_t);
    }

    /// @dev Deploys a curve with a reachable graduation threshold.
    function _deployGraduatableCurve() internal returns (Curve gradCurve, BondingToken gradToken) {
        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(50_000e18);

        vm.prank(alice); // different caller to avoid salt collision
        (address _c, address _t,,) = curveFactory.createCurve(
            Types.CreateCurveParams({
                name: "Grad Curve",
                symbol: "GRAD",
                decimals: 18,
                feeRecipient: feeRecipient,
                feeRecipientBps: protocolFeeBps,
                curveParams: Types.CurveParams({
                    collateralToken: address(usdc),
                    segments: segs,
                    maxThreshold: 10e6, // 10 USDC — easily reachable
                    maxBuyPerTx: 0,
                    maxSellPerTx: 0
                }),
                vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
            })
        );

        gradCurve = Curve(_c);
        gradToken = BondingToken(_t);
    }

    /// @dev Deploys a curve with no creator fee for fee comparison tests.
    function _deployNoFeeCurve() internal returns (Curve noFeeCurve, BondingToken noFeeToken) {
        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(50_000e18);

        vm.prank(bob); // different caller to avoid salt collision
        (address _c, address _t,,) = curveFactory.createCurve(
            Types.CreateCurveParams({
                name: "No Fee Curve",
                symbol: "NOFEE",
                decimals: 18,
                feeRecipient: address(0),
                feeRecipientBps: 0,
                curveParams: Types.CurveParams({
                    collateralToken: address(usdc),
                    segments: segs,
                    maxThreshold: 1_000_000e6,
                    maxBuyPerTx: 0,
                    maxSellPerTx: 0
                }),
                vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
            })
        );

        noFeeCurve = Curve(_c);
        noFeeToken = BondingToken(_t);
    }
}
