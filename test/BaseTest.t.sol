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

    // Contract Addresses
    struct Addresses {
        address curveFactory;
        address feeRecipient;
        address protocolTreasury;
        address curveImplementation;
        address tokenImplementation;
        address vestingImplementation;
        address graduationManagerImplementation;  
    }

    mapping(uint64 chainId => Addresses addresses) public addresses;

    function setUp() public virtual {
        _prepareForks();

        _deployContracts();

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

        // Set up test accounts
        curveCreator = makeAddr("curveCreator");
        vm.label(curveCreator, "CurveCreator");
        alice = makeAddr("alice");
        vm.label(alice, "Alice");
        bob = makeAddr("bob");
        vm.label(bob, "Bob");
        eve = makeAddr("eve");
        vm.label(eve, "Eve");
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

    function _deployContracts() internal {
        for (uint64 i = 0; i < chainIds.length; i++) {
            vm.selectFork(forks[chainIds[i]]);

            // Deploy implementation contracts
            address curveImpl = address(new Curve());
            addresses[chainIds[i]].curveImplementation = curveImpl;
            vm.label(addresses[chainIds[i]].curveImplementation, "CurveImplementation");

            address vestingImpl = address(new Vesting());
            addresses[chainIds[i]].vestingImplementation = vestingImpl;
            vm.label(addresses[chainIds[i]].vestingImplementation, "VestingImplementation");

            address tokenImpl = address(new BondingToken());
            addresses[chainIds[i]].tokenImplementation = tokenImpl;
            vm.label(addresses[chainIds[i]].tokenImplementation, "TokenImplementation");

            address graduationManagerImpl = address(new GraduationManager());
            addresses[chainIds[i]].graduationManagerImplementation = graduationManagerImpl;
            vm.label(addresses[chainIds[i]].graduationManagerImplementation, "GraduationManagerImplementation");

            address treasury = makeAddr("protocolTreasury");
            addresses[chainIds[i]].protocolTreasury = treasury;
            vm.label(addresses[chainIds[i]].protocolTreasury, "ProtocolTreasury");

            address recipient = makeAddr("feeRecipient");
            addresses[chainIds[i]].feeRecipient = recipient;
            vm.label(addresses[chainIds[i]].feeRecipient, "FeeRecipient");

            addresses[chainIds[i]].curveFactory = address(new CurveFactory(
            address(curveImplementation),
                addresses[chainIds[i]].tokenImplementation,
                addresses[chainIds[i]].vestingImplementation,
                addresses[chainIds[i]].graduationManagerImplementation,
                addresses[chainIds[i]].protocolTreasury,
                protocolFeeBps
            ));
            vm.label(addresses[chainIds[i]].curveFactory, "CurveFactory");
        }
    }
}