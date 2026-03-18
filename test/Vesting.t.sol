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

    /*//////////////////////////////////////////////////////////////
                    CLAIMABLE: VIEW FUNCTION
    //////////////////////////////////////////////////////////////*/

    // ── Before cliff ────────────────────────────────────────────

    function test_claimable_beforeCliff_isZero() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Warp to just before cliff ends
        vm.warp(block.timestamp + CLIFF - 1);
        assertEq(vesting.claimable(alice), 0);
    }

    function test_claimable_atExactCliff_isZero() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // elapsed == cliff → vestedElapsed = 0 → nothing unlocked yet
        vm.warp(block.timestamp + CLIFF);
        assertEq(vesting.claimable(alice), 0);
    }

    // ── After cliff, partial vesting ────────────────────────────

    function test_claimable_oneSecondAfterCliff() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // 1 second of vesting: 1000e18 * 1 / 365 days
        vm.warp(block.timestamp + CLIFF + 1);
        uint256 expected = (VESTING_AMOUNT * 1) / DURATION;
        assertEq(vesting.claimable(alice), expected);
    }

    function test_claimable_halfwayThroughVesting() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Halfway: 1000e18 * (duration/2) / duration = 500e18
        vm.warp(block.timestamp + CLIFF + DURATION / 2);
        assertEq(vesting.claimable(alice), VESTING_AMOUNT / 2);
    }

    // ── Fully vested ────────────────────────────────────────────

    function test_claimable_fullyVested() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        vm.warp(block.timestamp + CLIFF + DURATION);
        assertEq(vesting.claimable(alice), VESTING_AMOUNT);
    }

    function test_claimable_wellPastVesting() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Way past vesting — still capped at totalAmount
        vm.warp(block.timestamp + CLIFF + DURATION * 10);
        assertEq(vesting.claimable(alice), VESTING_AMOUNT);
    }

    // ── No schedule ─────────────────────────────────────────────

    function test_claimable_noSchedule_isZero() public view {
        assertEq(vesting.claimable(bob), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          CLAIM
    //////////////////////////////////////////////////////////////*/

    // ── Successful claim ────────────────────────────────────────

    function test_claim_transfersTokens() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Fully vested
        vm.warp(block.timestamp + CLIFF + DURATION);

        uint256 balanceBefore = vestingToken.balanceOf(alice);
        vm.prank(alice);
        vesting.claim();
        uint256 balanceAfter = vestingToken.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, VESTING_AMOUNT);
    }

    function test_claim_updatesClaimed() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        vm.warp(block.timestamp + CLIFF + DURATION);
        vm.prank(alice);
        vesting.claim();

        (,, uint256 claimed) = vesting.schedules(alice);
        assertEq(claimed, VESTING_AMOUNT);
    }

    function test_claim_partialVesting() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Halfway through vesting → 500e18 claimable
        vm.warp(block.timestamp + CLIFF + DURATION / 2);

        vm.prank(alice);
        vesting.claim();

        uint256 balance = vestingToken.balanceOf(alice);
        assertEq(balance, VESTING_AMOUNT / 2);
    }

    // ── Multiple claims over time ───────────────────────────────

    function test_claim_twoPartialClaims() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // First claim at 25% vesting
        vm.warp(block.timestamp + CLIFF + DURATION / 4);
        vm.prank(alice);
        vesting.claim();
        uint256 firstClaim = vestingToken.balanceOf(alice);
        assertEq(firstClaim, VESTING_AMOUNT / 4);

        // Second claim at 75% vesting
        vm.warp(block.timestamp + DURATION / 2);
        vm.prank(alice);
        vesting.claim();
        uint256 totalClaimed = vestingToken.balanceOf(alice);
        // 75% of total - 25% already claimed = 50% more
        assertEq(totalClaimed, (VESTING_AMOUNT * 3) / 4);
    }

    function test_claim_thenClaimRemainder() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Claim halfway
        vm.warp(block.timestamp + CLIFF + DURATION / 2);
        vm.prank(alice);
        vesting.claim();

        // Claim remainder after full vesting
        vm.warp(block.timestamp + DURATION);
        vm.prank(alice);
        vesting.claim();

        assertEq(vestingToken.balanceOf(alice), VESTING_AMOUNT);
    }

    // ── Reverts ─────────────────────────────────────────────────

    function test_claim_reverts_beforeCliff() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        vm.warp(block.timestamp + CLIFF - 1);
        vm.prank(alice);
        vm.expectRevert(IVesting.NOTHING_TO_CLAIM.selector);
        vesting.claim();
    }

    function test_claim_reverts_noSchedule() public {
        vm.prank(bob);
        vm.expectRevert(IVesting.NOTHING_TO_CLAIM.selector);
        vesting.claim();
    }

    function test_claim_reverts_alreadyClaimedAll() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Fully vested, claim everything
        vm.warp(block.timestamp + CLIFF + DURATION);
        vm.prank(alice);
        vesting.claim();

        // Try to claim again — nothing left
        vm.prank(alice);
        vm.expectRevert(IVesting.NOTHING_TO_CLAIM.selector);
        vesting.claim();
    }

    function test_claim_reverts_nothingNewSinceLastClaim() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        // Claim at halfway
        vm.warp(block.timestamp + CLIFF + DURATION / 2);
        vm.prank(alice);
        vesting.claim();

        // Try to claim again immediately — no new tokens vested
        vm.prank(alice);
        vm.expectRevert(IVesting.NOTHING_TO_CLAIM.selector);
        vesting.claim();
    }

    // ── Events ──────────────────────────────────────────────────

    function test_claim_emitsEvent() public {
        _addVestingAndFund(alice, VESTING_AMOUNT);

        vm.warp(block.timestamp + CLIFF + DURATION);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit IVesting.Claimed(alice, VESTING_AMOUNT);
        vesting.claim();
    }

    // ── Incremental vesting + claim interaction ─────────────────

    function test_claim_afterIncrementalAddVesting() public {
        // First allocation
        vm.warp(100);
        vm.prank(mockCurve);
        vesting.addVesting(alice, 600e18);

        // Second allocation later (startTime stays at 100)
        vm.warp(200);
        vm.prank(mockCurve);
        vesting.addVesting(alice, 400e18);

        // Fund the contract with total amount
        deal(address(vestingToken), address(vesting), 1000e18);

        // Fully vested from startTime=100
        vm.warp(100 + CLIFF + DURATION);
        vm.prank(alice);
        vesting.claim();

        // Should receive full 1000e18 (both allocations)
        assertEq(vestingToken.balanceOf(alice), 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // ── Claimable is always ≤ totalAmount ────────────────────────

    function testFuzz_claimable_neverExceedsTotal(
        uint256 amount,
        uint256 elapsed
    ) public {
        amount = bound(amount, 1e18, 1_000_000e18);
        elapsed = bound(elapsed, 0, CLIFF + DURATION * 2);

        _addVestingAndFund(alice, amount);
        vm.warp(block.timestamp + elapsed);

        uint256 claimableAmt = vesting.claimable(alice);
        assertTrue(claimableAmt <= amount);
    }

    // ── Claimable is zero before cliff ──────────────────────────

    function testFuzz_claimable_zeroBeforeCliff(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, CLIFF);

        _addVestingAndFund(alice, VESTING_AMOUNT);
        vm.warp(block.timestamp + elapsed);

        assertEq(vesting.claimable(alice), 0);
    }

    // ── Claimable monotonically increases with time ─────────────

    function testFuzz_claimable_monotonicallyIncreases(
        uint256 t1,
        uint256 t2
    ) public {
        t1 = bound(t1, CLIFF, CLIFF + DURATION);
        t2 = bound(t2, t1, CLIFF + DURATION);

        _addVestingAndFund(alice, VESTING_AMOUNT);

        vm.warp(block.timestamp + t1);
        uint256 c1 = vesting.claimable(alice);

        vm.warp(block.timestamp + (t2 - t1));
        uint256 c2 = vesting.claimable(alice);

        assertTrue(c2 >= c1);
    }

    // ── Fully vested after cliff + duration ─────────────────────

    function testFuzz_claimable_fullyVestedAfterDuration(
        uint256 amount,
        uint256 extra
    ) public {
        amount = bound(amount, 1e18, 1_000_000e18);
        extra = bound(extra, 0, 365 days);

        _addVestingAndFund(alice, amount);
        vm.warp(block.timestamp + CLIFF + DURATION + extra);

        assertEq(vesting.claimable(alice), amount);
    }

    // ── Linear proportionality: claimable ≈ total * elapsed / duration

    function testFuzz_claimable_linearProportionality(
        uint256 vestedElapsed
    ) public {
        vestedElapsed = bound(vestedElapsed, 1, DURATION - 1);

        _addVestingAndFund(alice, VESTING_AMOUNT);
        vm.warp(block.timestamp + CLIFF + vestedElapsed);

        uint256 expected = (VESTING_AMOUNT * vestedElapsed) / DURATION;
        assertEq(vesting.claimable(alice), expected);
    }

    // ── Claim drains exactly claimable amount ───────────────────

    function testFuzz_claim_drainsExactClaimable(
        uint256 elapsed
    ) public {
        elapsed = bound(elapsed, CLIFF + 1, CLIFF + DURATION);

        _addVestingAndFund(alice, VESTING_AMOUNT);
        vm.warp(block.timestamp + elapsed);

        uint256 expectedClaim = vesting.claimable(alice);
        vm.assume(expectedClaim > 0);

        vm.prank(alice);
        vesting.claim();

        assertEq(vestingToken.balanceOf(alice), expectedClaim);
        assertEq(vesting.claimable(alice), 0);
    }

    // ── Multiple claims sum to total ────────────────────────────

    function testFuzz_claim_multipleClaims_sumToTotal(
        uint256 t1,
        uint256 t2
    ) public {
        t1 = bound(t1, CLIFF + 1, CLIFF + DURATION / 2);
        t2 = bound(t2, CLIFF + DURATION / 2 + 1, CLIFF + DURATION);

        _addVestingAndFund(alice, VESTING_AMOUNT);

        // First claim
        vm.warp(block.timestamp + t1);
        uint256 c1 = vesting.claimable(alice);
        if (c1 > 0) {
            vm.prank(alice);
            vesting.claim();
        }

        // Second claim
        vm.warp(block.timestamp + (t2 - t1));
        uint256 c2 = vesting.claimable(alice);
        if (c2 > 0) {
            vm.prank(alice);
            vesting.claim();
        }

        // Final claim after full vesting
        vm.warp(block.timestamp + CLIFF + DURATION);
        uint256 c3 = vesting.claimable(alice);
        if (c3 > 0) {
            vm.prank(alice);
            vesting.claim();
        }

        // Total claimed should equal full amount
        assertEq(vestingToken.balanceOf(alice), VESTING_AMOUNT);
    }

    // ── Claim never transfers more than balance ─────────────────

    function testFuzz_claim_neverExceedsContractBalance(
        uint256 amount,
        uint256 elapsed
    ) public {
        amount = bound(amount, 1e18, 1_000_000e18);
        elapsed = bound(elapsed, CLIFF + 1, CLIFF + DURATION);

        _addVestingAndFund(alice, amount);
        vm.warp(block.timestamp + elapsed);

        uint256 contractBalBefore = vestingToken.balanceOf(address(vesting));
        uint256 claimableAmt = vesting.claimable(alice);

        assertTrue(claimableAmt <= contractBalBefore);
    }
}
