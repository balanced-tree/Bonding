// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import * as Types from "../src/Types.sol";

// Forge Std
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

// Contracts
import { Curve } from "../src/contracts/Curve.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { CurveFactory } from "../src/contracts/CurveFactory.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { GraduationManager } from "../src/contracts/GraduationManager.sol";

// Openzeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BaseTest is Test {
    using Clones for address;

    /// @notice Test accounts
    address public curveCreator;
    address public alice;
    address public bob;
    address public eve;

    /// @notice Fee recipient addresses
    address public feeRecipient;
    address public protocolTreasury;

    /// @notice Protocol contracts
    CurveFactory public curveFactory;

    /// @notice Implementation contracts
    Curve public curveImplementation;
    Vesting public vestingImplementation;
    BondingToken public tokenImplementation;
    GraduationManager public graduationManagerImplementation;

    /// @notice Protocol fee
    uint256 public protocolFeeBps;

    function setUp() public virtual {
        // Deploy implementation contracts
        curveImplementation = new Curve();
        vestingImplementation = new Vesting();
        tokenImplementation = new BondingToken();
        graduationManagerImplementation = new GraduationManager();

        // Deploy protocol treasury and set fee 
        protocolTreasury = makeAddr("protocolTreasury");
        vm.label(protocolTreasury, "ProtocolTreasury");
        protocolFeeBps = 1000; // 10%

        // Deploy fee recipient
        feeRecipient = makeAddr("feeRecipient");
        vm.label(feeRecipient, "FeeRecipient");

        // Label contracts 
        vm.label(address(curveFactory), "CurveFactory");
        vm.label(address(curveImplementation), "CurveImplementation");
        vm.label(address(tokenImplementation), "TokenImplementation");
        vm.label(address(vestingImplementation), "VestingImplementation");
        vm.label(address(graduationManagerImplementation), "GraduationManagerImplementation");

        // Set up test accounts
        curveCreator = makeAddr("curveCreator");
        vm.label(curveCreator, "CurveCreator");
        alice = makeAddr("alice");
        vm.label(alice, "Alice");
        bob = makeAddr("bob");
        vm.label(bob, "Bob");
        eve = makeAddr("eve");
        vm.label(eve, "Eve");

        // Deploy protocol contracts
        curveFactory = new CurveFactory(
            address(curveImplementation),
            address(tokenImplementation),
            address(vestingImplementation),
            address(graduationManagerImplementation),
            protocolTreasury,
            protocolFeeBps
        );
    }
}