// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Testing
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { Vesting } from "../src/contracts/Vesting.sol";
import { IVesting } from "../src/interfaces/IVesting.sol";

// OpenZeppelin
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract VestingTest is BaseTest {
    using Clones for address;

    Vesting public vesting;
    address public mockToken;
    address public mockCurve;

    uint256 public constant CLIFF = 30 days;
    uint256 public constant DURATION = 365 days;

    function setUp() public override {
        super.setUp();

        mockToken = makeAddr("mockToken");
        mockCurve = makeAddr("mockCurve");

        // Deploy as a clone and initialize
        address clone = address(vestingImplementation).clone();
        vesting = Vesting(clone);
        vesting.initialize(mockToken, mockCurve, CLIFF, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsToken() public view {
        assertEq(vesting.token(), mockToken);
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
        v.initialize(mockToken, mockCurve, 0, DURATION);
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
        v.initialize(mockToken, address(0), CLIFF, DURATION);
    }

    function test_initialize_reverts_zeroDuration() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectRevert(IVesting.INVALID_DURATION.selector);
        v.initialize(mockToken, mockCurve, CLIFF, 0);
    }

    function test_initialize_reverts_cannotReinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vesting.initialize(mockToken, mockCurve, CLIFF, DURATION);
    }

    function test_initialize_reverts_implementationLocked() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vestingImplementation.initialize(mockToken, mockCurve, CLIFF, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                      INITIALIZATION: EVENTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_emitsEvent() public {
        address clone = address(vestingImplementation).clone();
        Vesting v = Vesting(clone);
        vm.expectEmit(true, false, false, false);
        emit IVesting.Initialized(mockCurve);
        v.initialize(mockToken, mockCurve, CLIFF, DURATION);
    }
}
