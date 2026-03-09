// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Forge Std
import { Test } from "forge-std/Test.sol";

// Types
import * as Types from "../src/Types.sol";

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
    function setUp() public virtual {
        // Setup
    }
}