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
}