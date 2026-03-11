// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Contracts
import { Curve } from "../src/contracts/Curve.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { ICurveFactory } from "../src/interfaces/ICurveFactory.sol";

import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

contract CurveFactoryTest is BaseTest, Helpers {
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                      SUCCESS: SINGLE SEGMENT CURVES
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_singleLinear() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        (address curve, address token, address vesting, address graduationManager) =
            curveFactory.createCurve(_defaultParams(segs));

        // All addresses should be non-zero except vesting (no vesting config)
        assertTrue(curve != address(0));
        assertTrue(token != address(0));
        assertEq(vesting, address(0));
        assertTrue(graduationManager != address(0));

        // Registry state
        assertEq(curveFactory.getCurveCount(), 1);
        assertTrue(curveFactory.isCurve(curve));
        assertEq(curveFactory.getCurves()[0], curve);

        // Mapping lookups
        assertEq(curveFactory.getToken(curve), token);
        assertEq(curveFactory.getVesting(curve), address(0));
        assertEq(curveFactory.getGraduationManager(curve), graduationManager);

        // Verify Curve was initialized correctly
        Curve curveContract = Curve(curve);
        assertEq(curveContract.token(), token);
        assertEq(curveContract.collateralToken(), address(usdc));
        assertEq(curveContract.treasury(), curveFactory.PROTOCOL_TREASURY());
        assertEq(curveContract.protocolFeeBps(), curveFactory.PROTOCOL_FEE_BPS());
        assertEq(curveContract.maxThreshold(), 1e18);
        assertEq(curveContract.maxBuyPerTx(), 10_000);
        assertEq(curveContract.maxSellPerTx(), 10_000);
        assertEq(curveContract.feeRecipient(), feeRecipient);
        assertEq(curveContract.feeRecipientBps(), protocolFeeBps);
        assertFalse(curveContract.graduated());

        // Verify token was initialized correctly
        BondingToken tokenContract = BondingToken(token);
        assertEq(tokenContract.name(), "Test Curve");
        assertEq(tokenContract.symbol(), "TEST");
        assertEq(tokenContract.decimals(), 18);
    }

    function test_createCurve_singleLn() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLnSegment(0, 1e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_singleParabolic() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createParabolicSegment(0, 1e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_singleExponential() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createExponentialSegment(0, 1e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_singleSigmoid() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createSigmoidSegment(0, 10e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_singleSin() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createSinSegment(0, 1e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS: MULTI-SEGMENT CURVES
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_twoSegments_linearLinear() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearLinearSegments(500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertEq(curveFactory.getCurveCount(), 1);
        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_twoSegments_linearLn() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearLnSegments(500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_twoSegments_linearExponential() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearExponentialSegments(500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_twoSegments_linearParabolic() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_twoSegments_linearSigmoid() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearSigmoidSegments(500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_threeSegments_linearParabolicExponential() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearParabolicExponentialSegments(100e18, 500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_threeSegments_linearLnSigmoid() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearLnSigmoidSegments(100e18, 500e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS: VESTING CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_withVesting() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.vestingConfig = Types.VestingConfig({ cliffDuration: 30 days, vestingDuration: 180 days });

        (address curve,, address vesting,) = curveFactory.createCurve(params);

        assertTrue(vesting != address(0));
        assertEq(curveFactory.getVesting(curve), vesting);
    }

    function test_createCurve_noVesting_cliffZero() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        // cliffDuration = 0 means no vesting even if vestingDuration > 0
        params.vestingConfig = Types.VestingConfig({ cliffDuration: 0, vestingDuration: 180 days });

        (,, address vesting,) = curveFactory.createCurve(params);

        assertEq(vesting, address(0));
    }

    function test_createCurve_noVesting_durationZero() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        // vestingDuration = 0 means no vesting even if cliffDuration > 0
        params.vestingConfig = Types.VestingConfig({ cliffDuration: 30 days, vestingDuration: 0 });

        (,, address vesting,) = curveFactory.createCurve(params);

        assertEq(vesting, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS: FEE RECIPIENT VARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_noFeeRecipient() public {
        vm.startPrank(curveCreator);

        Types.CreateCurveParams memory params = _defaultParamsNoFee();

        (address curve,,,) = curveFactory.createCurve(params);

        Curve curveContract = Curve(curve);
        assertEq(curveContract.feeRecipient(), address(0));
        assertEq(curveContract.feeRecipientBps(), 0);
    }

    function test_createCurve_withFeeRecipient() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = makeAddr("customFeeRecipient");
        params.feeRecipientBps = 500; // 5%

        (address curve,,,) = curveFactory.createCurve(params);

        Curve curveContract = Curve(curve);
        assertEq(curveContract.feeRecipient(), makeAddr("customFeeRecipient"));
        assertEq(curveContract.feeRecipientBps(), 500);
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS: EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_emitsCurveCreated() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        // We can't predict exact addresses, so just check the event is emitted
        // by checking topic count (indexed params) via expectEmit
        vm.expectEmit(false, false, true, false);
        emit ICurveFactory.CurveCreated(address(0), address(0), curveCreator, address(0), address(0));

        curveFactory.createCurve(_defaultParams(segs));
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS: MULTIPLE CURVES
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_multipleCurves() public {
        vm.startPrank(curveCreator);

        // Create first curve
        Types.PiecewiseSegment[] memory segs1 = new Types.PiecewiseSegment[](1);
        segs1[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params1 = _defaultParams(segs1);
        params1.name = "Curve One";
        params1.symbol = "ONE";

        (address curve1,,,) = curveFactory.createCurve(params1);

        // Create second curve (different config to get different salt)
        Types.PiecewiseSegment[] memory segs2 = new Types.PiecewiseSegment[](1);
        segs2[0] = _createParabolicSegment(0, 2e18);

        Types.CreateCurveParams memory params2 = _defaultParams(segs2);
        params2.name = "Curve Two";
        params2.symbol = "TWO";

        (address curve2,,,) = curveFactory.createCurve(params2);

        assertEq(curveFactory.getCurveCount(), 2);
        assertTrue(curveFactory.isCurve(curve1));
        assertTrue(curveFactory.isCurve(curve2));
        assertTrue(curve1 != curve2);

        address[] memory curves = curveFactory.getCurves();
        assertEq(curves.length, 2);
        assertEq(curves[0], curve1);
        assertEq(curves[1], curve2);
    }

    function test_createCurve_differentCallersCanUseSameConfig() public {
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);
        Types.CreateCurveParams memory params = _defaultParams(segs);

        vm.prank(curveCreator);
        (address curve1,,,) = curveFactory.createCurve(params);

        vm.prank(alice);
        (address curve2,,,) = curveFactory.createCurve(params);

        assertTrue(curve1 != curve2);
        assertEq(curveFactory.getCurveCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                REVERT: COLLATERAL TOKEN VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_revert_zeroCollateralToken() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.curveParams.collateralToken = address(0);

        vm.expectRevert(ICurveFactory.INVALID_CONFIG.selector);
        curveFactory.createCurve(params);
    }

    /*//////////////////////////////////////////////////////////////
                REVERT: SEGMENT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_revert_emptySegments() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](0);

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_tooManySegments() public {
        vm.startPrank(curveCreator);

        // MAX_SEGMENTS = 3, so 4 should fail
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](4);
        segs[0] = _createLinearSegment(0, 100e18);
        segs[1] = _createLinearSegment(100e18, 200e18);
        segs[2] = _createLinearSegment(200e18, 300e18);
        segs[3] = _createLinearSegment(300e18, 400e18);

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_firstSegmentNotStartingAtZero() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(1e18, 2e18);

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_segmentStartEqualsEnd() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 0); // start == end

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_segmentStartGreaterThanEnd() public {
        vm.startPrank(curveCreator);

        // Build manually since helper would set supplyStart < supplyEnd
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = Types.PiecewiseSegment({
            supplyStart: 0,
            supplyEnd: 0,
            formulaType: Types.FormulaType.LINEAR,
            encodedParams: abi.encode(Types.LinearParams({ m: 1e18, b: 0 }))
        });

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_nonContiguousSegments_gap() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](2);
        segs[0] = _createLinearSegment(0, 100e18);
        segs[1] = _createLinearSegment(200e18, 300e18); // gap: 100e18 → 200e18

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_nonContiguousSegments_overlap() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](2);
        segs[0] = _createLinearSegment(0, 200e18);
        segs[1] = _createLinearSegment(100e18, 300e18); // overlap: 100e18 → 200e18

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    function test_createCurve_revert_threeSegments_middleInvalid() public {
        vm.startPrank(curveCreator);

        // Second segment has start == end
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](3);
        segs[0] = _createLinearSegment(0, 100e18);
        segs[1] = _createLinearSegment(100e18, 100e18); // invalid: start == end
        segs[2] = _createLinearSegment(100e18, 200e18);

        vm.expectRevert(ICurveFactory.INVALID_SEGMENTS.selector);
        curveFactory.createCurve(_defaultParams(segs));
    }

    /*//////////////////////////////////////////////////////////////
                REVERT: FEE RECIPIENT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_revert_feeRecipientZeroWithNonZeroBps() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = address(0);
        params.feeRecipientBps = 500;

        vm.expectRevert(ICurveFactory.INVALID_CONFIG.selector);
        curveFactory.createCurve(params);
    }

    function test_createCurve_revert_feeRecipientNonZeroWithZeroBps() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = makeAddr("someRecipient");
        params.feeRecipientBps = 0;

        vm.expectRevert(ICurveFactory.INVALID_CONFIG.selector);
        curveFactory.createCurve(params);
    }

    function test_createCurve_revert_combinedFeesExceedMax() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = makeAddr("someRecipient");
        // protocolFeeBps = 1000 (10%), so setting 2100 (21%) exceeds MAX_FEE_BPS of 3000 (30%)
        params.feeRecipientBps = 2100;

        vm.expectRevert(ICurveFactory.INVALID_FEE_BPS.selector);
        curveFactory.createCurve(params);
    }

    function test_createCurve_revert_combinedFeesExactlyAtMax() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = makeAddr("someRecipient");
        // protocolFeeBps = 1000 (10%) + 2000 (20%) = 3000 = MAX_FEE_BPS — should succeed
        params.feeRecipientBps = 2000;

        // Should NOT revert — exactly at limit
        (address curve,,,) = curveFactory.createCurve(params);
        assertTrue(curveFactory.isCurve(curve));
    }

    function test_createCurve_revert_combinedFeesOneOverMax() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = makeAddr("someRecipient");
        // protocolFeeBps = 1000 + 2001 = 3001 > MAX_FEE_BPS (3000)
        params.feeRecipientBps = 2001;

        vm.expectRevert(ICurveFactory.INVALID_FEE_BPS.selector);
        curveFactory.createCurve(params);
    }

    /*//////////////////////////////////////////////////////////////
              REVERT: DETERMINISTIC CLONE COLLISION
    //////////////////////////////////////////////////////////////*/

    function test_createCurve_revert_duplicateConfigSameCaller() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);

        // First call succeeds
        curveFactory.createCurve(params);

        // Second call with identical config + same msg.sender → same salt → clone collision
        vm.expectRevert();
        curveFactory.createCurve(params);
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS: getCurveCount
    //////////////////////////////////////////////////////////////*/

    function test_getCurveCount_initiallyZero() public view {
        assertEq(curveFactory.getCurveCount(), 0);
    }

    function test_getCurveCount_incrementsAfterCreation() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        assertEq(curveFactory.getCurveCount(), 0);

        Types.CreateCurveParams memory params1 = _defaultParams(segs);
        params1.name = "First";
        params1.symbol = "A";
        curveFactory.createCurve(params1);
        assertEq(curveFactory.getCurveCount(), 1);

        Types.CreateCurveParams memory params2 = _defaultParams(segs);
        params2.name = "Second";
        params2.symbol = "B";
        curveFactory.createCurve(params2);
        assertEq(curveFactory.getCurveCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS: isCurve
    //////////////////////////////////////////////////////////////*/

    function test_isCurve_falseForRandomAddress() public {
        assertFalse(curveFactory.isCurve(makeAddr("random")));
    }

    function test_isCurve_falseForZeroAddress() public view {
        assertFalse(curveFactory.isCurve(address(0)));
    }

    function test_isCurve_trueAfterCreation() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        (address curve,,,) = curveFactory.createCurve(_defaultParams(segs));

        assertTrue(curveFactory.isCurve(curve));
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS: getCurves
    //////////////////////////////////////////////////////////////*/

    function test_getCurves_emptyInitially() public view {
        address[] memory curves = curveFactory.getCurves();
        assertEq(curves.length, 0);
    }

    function test_getCurves_returnsAllCurves() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params1 = _defaultParams(segs);
        params1.name = "C1";
        params1.symbol = "C1";
        (address c1,,,) = curveFactory.createCurve(params1);

        Types.CreateCurveParams memory params2 = _defaultParams(segs);
        params2.name = "C2";
        params2.symbol = "C2";
        (address c2,,,) = curveFactory.createCurve(params2);

        address[] memory curves = curveFactory.getCurves();
        assertEq(curves.length, 2);
        assertEq(curves[0], c1);
        assertEq(curves[1], c2);
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS: getCurve (by index)
    //////////////////////////////////////////////////////////////*/

    function test_getCurve_byIndex() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params1 = _defaultParams(segs);
        params1.name = "Idx0";
        params1.symbol = "I0";
        (address c0,,,) = curveFactory.createCurve(params1);

        Types.CreateCurveParams memory params2 = _defaultParams(segs);
        params2.name = "Idx1";
        params2.symbol = "I1";
        (address c1,,,) = curveFactory.createCurve(params2);

        assertEq(curveFactory.getCurve(0), c0);
        assertEq(curveFactory.getCurve(1), c1);
    }

    function test_getCurve_revert_outOfBounds() public {
        vm.expectRevert(); // array OOB
        curveFactory.getCurve(0);
    }

    /*//////////////////////////////////////////////////////////////
                VIEW FUNCTIONS: getToken / getVesting / getGraduationManager
    //////////////////////////////////////////////////////////////*/

    function test_getToken_returnsZeroForUnknownCurve() public {
        assertEq(curveFactory.getToken(makeAddr("nonexistent")), address(0));
    }

    function test_getVesting_returnsZeroForUnknownCurve() public {
        assertEq(curveFactory.getVesting(makeAddr("nonexistent")), address(0));
    }

    function test_getGraduationManager_returnsZeroForUnknownCurve() public {
        assertEq(curveFactory.getGraduationManager(makeAddr("nonexistent")), address(0));
    }

    function test_getVesting_returnsAddressWhenVestingEnabled() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.vestingConfig = Types.VestingConfig({ cliffDuration: 7 days, vestingDuration: 90 days });

        (address curve,, address vesting,) = curveFactory.createCurve(params);

        assertEq(curveFactory.getVesting(curve), vesting);
        assertTrue(vesting != address(0));
    }

    function test_getToken_matchesCurveTokenState() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        (address curve, address token,,) = curveFactory.createCurve(_defaultParams(segs));

        // Factory lookup should match Curve's stored token
        assertEq(curveFactory.getToken(curve), token);
        assertEq(Curve(curve).token(), token);
    }

    function test_getGraduationManager_matchesCurveState() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);

        (address curve,,, address gm) = curveFactory.createCurve(_defaultParams(segs));

        assertEq(curveFactory.getGraduationManager(curve), gm);
        assertEq(Curve(curve).graduationManager(), gm);
    }

    /*//////////////////////////////////////////////////////////////
                VIEW FUNCTIONS: IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    function test_immutables() public view {
        assertEq(curveFactory.PROTOCOL_FEE_BPS(), protocolFeeBps);
        assertEq(curveFactory.PROTOCOL_TREASURY(), protocolTreasury);
        assertEq(curveFactory.CURVE_IMPLEMENTATION(), address(curveImplementation));
        assertEq(curveFactory.TOKEN_IMPLEMENTATION(), address(tokenImplementation));
        assertEq(curveFactory.VESTING_IMPLEMENTATION(), address(vestingImplementation));
        assertEq(curveFactory.GRADUATION_MANAGER_IMPLEMENTATION(), address(graduationManagerImplementation));
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER: DEFAULT PARAMS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a valid CreateCurveParams with a single linear segment.
    function _defaultParams(
        Types.PiecewiseSegment[] memory segments
    ) internal view returns (Types.CreateCurveParams memory) {
        return Types.CreateCurveParams({
            name: "Test Curve",
            symbol: "TEST",
            decimals: 18,
            feeRecipient: feeRecipient,
            feeRecipientBps: protocolFeeBps,
            curveParams: Types.CurveParams({
                collateralToken: address(usdc),
                segments: segments,
                maxThreshold: 1e18,
                maxBuyPerTx: 10_000,
                maxSellPerTx: 10_000
            }),
            vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
        });
    }

    /// @dev Overload with no-fee-recipient defaults and a single linear segment.
    function _defaultParamsNoFee() internal view returns (Types.CreateCurveParams memory) {
        Types.PiecewiseSegment[] memory segs = new Types.PiecewiseSegment[](1);
        segs[0] = _createLinearSegment(0, 1e18);
        Types.CreateCurveParams memory params = _defaultParams(segs);
        params.feeRecipient = address(0);
        params.feeRecipientBps = 0;
        return params;
    }
}
