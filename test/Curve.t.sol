// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Contracts
import { Curve } from "../src/contracts/Curve.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { ICurveFactory } from "../src/interfaces/ICurveFactory.sol";
import { GraduationManager } from "../src/contracts/GraduationManager.sol";

import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

contract CurveTest is BaseTest, Helpers {
    Curve public curve;
    Vesting public vesting;
    BondingToken public token;
    GraduationManager public graduationManager;
    
    function setUp() public override {
        super.setUp();

        vm.startPrank(curveCreator);

        Types.PiecewiseSegment[] memory segs = _createLinearParabolicSegments(500e18);

        (address curve, address token, address vesting, address graduationManager) =
            curveFactory.createCurve(
                Types.CreateCurveParams({
                    name: "Test Curve",
                    symbol: "TEST",
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

        curve = Curve(curve);
        token = BondingToken(token);
        vesting = Vesting(vesting);
        graduationManager = GraduationManager(graduationManager);
    }

    function test_initialize() public {
        assertEq(curve.token(), address(token));
    }
}