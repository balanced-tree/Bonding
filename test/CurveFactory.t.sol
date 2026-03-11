// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

contract CurveFactoryTest is BaseTest, Helpers {
    function setUp() public override {
        super.setUp();
    }

    function test_createCurve() public {
        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segment = new Types.PiecewiseSegment[](1);
        segment[0] = Types.PiecewiseSegment({
            supplyStart: 0,
            supplyEnd: 1e18,
            formulaType: Types.FormulaType.LINEAR,
            encodedParams: abi.encode(Types.LinearParams({ m: 1e18, b: 0 }))
        });

        (address curve, address token, address vesting, address graduationManager) = curveFactory.createCurve(
            Types.CreateCurveParams({
                name: "Test Curve",
                symbol: "TEST",
                decimals: 18,
                feeRecipient: feeRecipient,
                feeRecipientBps: protocolFeeBps,
                curveParams: Types.CurveParams({
                    collateralToken: address(usdc),
                    segments: segment,
                    maxThreshold: 1e18,
                    maxBuyPerTx: 10_000,
                    maxSellPerTx: 10_000
                }),
                vestingConfig: Types.VestingConfig({ cliffDuration: 0, vestingDuration: 0 })
            })
        );

        assertEq(curveFactory.getCurveCount(), 1);
        assertEq(curveFactory.isCurve(address(curve)), true);
        assertEq(curveFactory.getCurves()[0], address(curve));

        assertEq(curveFactory.getToken(address(curve)), address(token));
        assertEq(curveFactory.getVesting(address(curve)), address(0));
        assertEq(curveFactory.getGraduationManager(address(curve)), address(graduationManager));
    }
}
