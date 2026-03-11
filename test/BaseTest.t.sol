// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Forge Std
import { Test } from "forge-std/Test.sol";

// Contracts
import { MockERC20 } from "./MockERC20.sol";
import { Curve } from "../src/contracts/Curve.sol";
import { Vesting } from "../src/contracts/Vesting.sol";
import { CurveFactory } from "../src/contracts/CurveFactory.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";
import { GraduationManager } from "../src/contracts/GraduationManager.sol";

// Openzeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract BaseTest is Test {
    using Clones for address;

    // Test accounts
    address public curveCreator;
    address public alice;
    address public bob;
    address public eve;

    // Fee recipient addresses
    address public feeRecipient;
    address public protocolTreasury;

    // Protocol contracts
    CurveFactory public curveFactory;

    // Implementation contracts
    Curve public curveImplementation;
    Vesting public vestingImplementation;
    BondingToken public tokenImplementation;
    GraduationManager public graduationManagerImplementation;

    // Protocol fee
    uint256 public protocolFeeBps;

    // Tokens
    MockERC20 public usdc;
    MockERC20 public wbtc;

    function setUp() public virtual {
        protocolFeeBps = 1000; // 10%

        // Create contract instances
        _deployContracts();

        // Set up tokens
        _setTokens();

        // Set up test accounts
        _makeTestAccounts();
        _fundAccounts(1000);
    }

    function _deployContracts() internal {
        curveImplementation = new Curve();
        vestingImplementation = new Vesting();
        tokenImplementation = new BondingToken();
        graduationManagerImplementation = new GraduationManager();

        feeRecipient = makeAddr("feeRecipient");
        protocolTreasury = makeAddr("protocolTreasury");

        curveFactory = new CurveFactory(
            address(curveImplementation),
            address(tokenImplementation),
            address(vestingImplementation),
            address(graduationManagerImplementation),
            address(protocolTreasury), 
            protocolFeeBps
        );
    }

    function _setTokens() internal {
        usdc = new MockERC20("USDC", "USDC", 6);
        wbtc = new MockERC20("WBTC", "WBTC", 18);
    }

    function _makeTestAccounts() internal {
        curveCreator = makeAddr("curveCreator");
        vm.makePersistent(curveCreator);
        vm.label(curveCreator, "CurveCreator");

        alice = makeAddr("alice");
        vm.makePersistent(alice);
        vm.label(alice, "Alice");

        bob = makeAddr("bob");
        vm.makePersistent(bob);
        vm.label(bob, "Bob");

        eve = makeAddr("eve");
        vm.makePersistent(eve);
        vm.label(eve, "Eve");
    }

    function _fundAccounts(uint256 amount) internal {
        deal(address(usdc), curveCreator, amount * (10 ** 6));
        deal(address(wbtc), curveCreator, amount * (10 ** 18));

        deal(address(usdc), alice, amount * (10 ** 6));
        deal(address(wbtc), alice, amount * (10 ** 18));

        deal(address(usdc), bob, amount * (10 ** 6));
        deal(address(wbtc), bob, amount * (10 ** 18));

        deal(address(usdc), eve, amount * (10 ** 6));
        deal(address(wbtc), eve, amount * (10 ** 18));
    }
}
