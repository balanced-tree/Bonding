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

    function test_initialize() public {
        assertEq(curve.token(), address(token));
    }
}