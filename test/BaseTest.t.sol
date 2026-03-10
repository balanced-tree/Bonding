// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import * as Types from "../src/Types.sol";
import { Constants } from "./Constants.sol";

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

contract BaseTest is Test, Constants {
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

    // Chain Config
    bool public useLatestFork = true;
    uint64[] public chainIds = [ETH, OP, BASE];
    string[] public chainsNames = [ETHEREUM_KEY, OPTIMISM_KEY, BASE_KEY];
    // chainID => FORK
    mapping(uint64 chainId => uint256 fork) public forks;
    mapping(uint64 chainId => string forkUrl) public rpcURLs;
    string public ethereumRpcUrl = vm.envString(ETHEREUM_RPC_URL_KEY);
    string public optimismRpcUrl = vm.envString(OPTIMISM_RPC_URL_KEY);
    string public baseRpcUrl = vm.envString(BASE_RPC_URL_KEY);

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

    function _prepareForks() internal {
        mapping(uint64 => uint256) storage forksPerChain = forks;

        if (useLatestFork) {
            forksPerChain[ETH] = vm.createFork(ethereumRpcUrl);
            forksPerChain[OP] = vm.createFork(optimismRpcUrl);
            forksPerChain[BASE] = vm.createFork(baseRpcUrl);
        } else {
            forksPerChain[ETH] = vm.createFork(ethereumRpcUrl, ETH_BLOCK);
            forksPerChain[OP] = vm.createFork(optimismRpcUrl, OP_BLOCK);
            forksPerChain[BASE] = vm.createFork(baseRpcUrl, BASE_BLOCK);
        }

        mapping(uint64 => string) storage rpc_urls = rpcURLs;
        rpc_urls[ETH] = ethereumRpcUrl;
        rpc_urls[OP] = optimismRpcUrl;
        rpc_urls[BASE] = baseRpcUrl;
    }
}