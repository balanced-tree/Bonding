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

    /*//////////////////////////////////////////////////////////////
                      INITIALIZATION: REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_revert_zeroMinter() public {
        address clone = address(tokenImplementation).clone();
        BondingToken newToken = BondingToken(clone);

        vm.expectRevert(BondingToken.INVALID_MINTER.selector);
        newToken.initialize("Token", "TKN", 18, address(0));
    }

    function test_initialize_revert_cannotReinitialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("New Name", "NEW", 8, alice);
    }

    function test_initialize_revert_implementationLocked() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        tokenImplementation.initialize("Impl", "IMPL", 18, minter);
    }

    /*//////////////////////////////////////////////////////////////
                              MINT
    //////////////////////////////////////////////////////////////*/

    function test_mint_success() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_mint_multipleRecipients() public {
        vm.startPrank(minter);
        token.mint(alice, 100e18);
        token.mint(bob, 200e18);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(bob), 200e18);
        assertEq(token.totalSupply(), 300e18);
    }

    function test_mint_revert_onlyMinter() public {
        vm.prank(alice);
        vm.expectRevert(BondingToken.ONLY_MINTER.selector);
        token.mint(alice, 1000e18);
    }

    
}
