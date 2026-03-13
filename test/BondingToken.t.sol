// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Testing
import { BaseTest } from "./BaseTest.t.sol";

// Contracts
import { BondingToken } from "../src/contracts/BondingToken.sol";

// OpenZeppelin
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract BondingTokenTest is BaseTest {
    using Clones for address;

    BondingToken public token;
    address public minter;

    function setUp() public override {
        super.setUp();

        minter = makeAddr("minter");

        // Deploy as a clone
        address clone = address(tokenImplementation).clone();
        token = BondingToken(clone);
        token.initialize("Test Token", "TEST", 18, minter);
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsName() public view {
        assertEq(token.name(), "Test Token");
    }

    function test_initialize_setsSymbol() public view {
        assertEq(token.symbol(), "TEST");
    }

    function test_initialize_setsDecimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_initialize_setsMinter() public view {
        assertEq(token.minter(), minter);
    }

    function test_initialize_zeroSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_initialize_customDecimals() public {
        address clone = address(tokenImplementation).clone();
        BondingToken token6 = BondingToken(clone);
        token6.initialize("USDC Token", "USDCT", 6, minter);

        assertEq(token6.decimals(), 6);
    }

    
}
