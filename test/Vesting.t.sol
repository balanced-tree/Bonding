// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Testing
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { MockERC20 } from "./MockERC20.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { IVesting } from "../src/interfaces/IVesting.sol";

// OpenZeppelin
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract VestingTest is BaseTest {
    using Clones for address;

    Vesting public vesting;
    MockERC20 public vestingToken;
    address public mockCurve;

    uint256 public constant CLIFF = 30 days;
    uint256 public constant DURATION = 365 days;
    uint256 public constant VESTING_AMOUNT = 1000e18;

    function setUp() public override {
        super.setUp();

        mockCurve = makeAddr("mockCurve");
        vestingToken = new MockERC20("Vesting Token", "VEST", 18);

        // Deploy as a clone and initialize
        address clone = address(vestingImplementation).clone();
        vesting = Vesting(clone);
        vesting.initialize(address(vestingToken), mockCurve, CLIFF, DURATION);
    }

    /// @dev Helper: add vesting for a beneficiary and fund the contract
    function _addVestingAndFund(address beneficiary, uint256 amount) internal {
        vm.prank(mockCurve);
        vesting.addVesting(beneficiary, amount);
        deal(address(vestingToken), address(vesting), amount);
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsToken() public view {
        assertEq(vesting.token(), address(vestingToken));
    }

    function test_initialize_setsCurve() public view {
        assertEq(vesting.curve(), mockCurve);
    }

    function test_initialize_setsCliffDuration() public view {
        assertEq(vesting.cliffDuration(), CLIFF);
    }

    function test_initialize_setsVestingDuration() public view {
        assertEq(vesting.vestingDuration(), DURATION);
    }

    function test_initialize_zeroCliffIsValid() public {
        // A vesting schedule with no cliff is valid
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        v.initialize(address(vestingToken), mockCurve, 0, DURATION);
        assertEq(v.cliffDuration(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                      INITIALIZATION: REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_reverts_zeroToken() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectRevert(IVesting.ZERO_ADDRESS.selector);
        v.initialize(address(0), mockCurve, CLIFF, DURATION);
    }

    function test_initialize_reverts_zeroCurve() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectRevert(IVesting.ZERO_ADDRESS.selector);
        v.initialize(address(vestingToken), address(0), CLIFF, DURATION);
    }

    function test_initialize_reverts_zeroDuration() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectRevert(IVesting.INVALID_DURATION.selector);
        v.initialize(address(vestingToken), mockCurve, CLIFF, 0);
    }

    function test_initialize_reverts_cannotReinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vesting.initialize(address(vestingToken), mockCurve, CLIFF, DURATION);
    }

    function test_initialize_reverts_implementationLocked() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vestingImplementation.initialize(address(vestingToken), mockCurve, CLIFF, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                      INITIALIZATION: EVENTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_emitsEvent() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectEmit(true, false, false, false);
        emit IVesting.Initialized(mockCurve);
        v.initialize(address(vestingToken), mockCurve, CLIFF, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                          ADD VESTING
    //////////////////////////////////////////////////////////////*/

    // ── First allocation ────────────────────────────────────────

    function test_addVesting_setsTotalAmount() public {
        vm.prank(mockCurve);
        vesting.addVesting(alice, 1000e18);

        (uint256 totalAmount,,) = vesting.schedules(alice);
        assertEq(totalAmount, 1000e18);
    }

    function test_addVesting_setsStartTime() public {
        vm.warp(1000);
        vm.prank(mockCurve);
        vesting.addVesting(alice, 1000e18);

        (, uint256 startTime,) = vesting.schedules(alice);
        assertEq(startTime, 1000);
    }

    function test_addVesting_claimedStartsAtZero() public {
        vm.prank(mockCurve);
        vesting.addVesting(alice, 1000e18);

        (,, uint256 claimed) = vesting.schedules(alice);
        assertEq(claimed, 0);
    }

    // ── Incremental allocations ─────────────────────────────────

    function test_addVesting_secondCallIncreasesTotalAmount() public {
        vm.startPrank(mockCurve);
        vesting.addVesting(alice, 1000e18);
        vesting.addVesting(alice, 500e18);
        vm.stopPrank();

        (uint256 totalAmount,,) = vesting.schedules(alice);
        assertEq(totalAmount, 1500e18);
    }

    function test_addVesting_secondCallPreservesStartTime() public {
        vm.warp(1000);
        vm.prank(mockCurve);
        vesting.addVesting(alice, 1000e18);

        // Second allocation at a later time
        vm.warp(2000);
        vm.prank(mockCurve);
        vesting.addVesting(alice, 500e18);

        (, uint256 startTime,) = vesting.schedules(alice);
        // startTime should still be 1000 (from first allocation)
        assertEq(startTime, 1000);
    }

    function test_addVesting_multipleBeneficiaries() public {
        vm.startPrank(mockCurve);
        vesting.addVesting(alice, 1000e18);
        vesting.addVesting(bob, 2000e18);
        vm.stopPrank();

        (uint256 aliceAmount,,) = vesting.schedules(alice);
        (uint256 bobAmount,,) = vesting.schedules(bob);
        assertEq(aliceAmount, 1000e18);
        assertEq(bobAmount, 2000e18);
    }

    // ── Access control ──────────────────────────────────────────

    function test_addVesting_reverts_notCurve() public {
        vm.prank(alice);
        vm.expectRevert(IVesting.ONLY_CURVE.selector);
        vesting.addVesting(alice, 1000e18);
    }

    function test_addVesting_reverts_zeroBeneficiary() public {
        vm.prank(mockCurve);
        vm.expectRevert(IVesting.INVALID_BENEFICIARY.selector);
        vesting.addVesting(address(0), 1000e18);
    }

    // ── Events ──────────────────────────────────────────────────

    function test_addVesting_emitsEvent() public {
        vm.prank(mockCurve);
        vm.expectEmit(true, false, false, true);
        emit IVesting.VestingAdded(alice, 1000e18);
        vesting.addVesting(alice, 1000e18);
    }

    function test_addVesting_emitsEventOnSecondCall() public {
        vm.startPrank(mockCurve);
        vesting.addVesting(alice, 1000e18);

        vm.expectEmit(true, false, false, true);
        emit IVesting.VestingAdded(alice, 500e18);
        vesting.addVesting(alice, 500e18);
        vm.stopPrank();
    }
}
