// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

// Testing
import { Helpers } from "./Helpers.sol";
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { Curve } from "../src/contracts/Curve.sol";
import { BondingToken } from "../src/contracts/BondingToken.sol";

contract BondingTokenTest is BaseTest, Helpers{
    Curve public curve;
    BondingToken public token;

    function setUp() public override {
        super.setUp();

    }
}