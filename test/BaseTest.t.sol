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

    /// @notice Protocol contracts
    address public curveFactory;
    address public feeRecipient;
    address public protocolTreasury;

    /// @notice Implementation contracts
    address public curveImplementation;
    address public tokenImplementation;
    address public vestingImplementation;
    address public graduationManagerImplementation;

    uint256 public protocolFeeBps;

    function setUp() public virtual {
        // Deploy implementation contracts
        curveImplementation = address(new Curve());
        tokenImplementation = address(new BondingToken());
        vestingImplementation = address(new Vesting());
        graduationManagerImplementation = address(new GraduationManager());

        // Deploy protocol treasury
        protocolTreasury = makeAddr("protocolTreasury");

        // Deploy protocol contracts
        curveFactory = address(
          new CurveFactory(
              curveImplementation,
              tokenImplementation,
              vestingImplementation,
              graduationManagerImplementation,
              protocolTreasury,
              protocolFeeBps
          )
        );

    }
}