// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;
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
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
    // Tokens
    string[] public tokenKeys = [DAI_KEY, USDC_KEY, WETH_KEY, WBTC_KEY];
    mapping(uint64 chainId => mapping(string tokenKey => address token)) public tokens;

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
        protocolFeeBps = 1000; // 10%

        // Set up fork chain config
        _prepareForks();

        // Deploy contract addresses
        _deployContracts(protocolFeeBps);

        // Set up tokens
        _setTokens();

        // Set up test accounts
        _makeTestAccounts();
        _fundAccounts(LARGE);

        // Set up test contract instances
        vm.selectFork(forks[ETH]);
        curveFactory = CurveFactory(addresses[ETH].curveFactory);
        curveImplementation = Curve(addresses[ETH].curveImplementation);
        vestingImplementation = Vesting(addresses[ETH].vestingImplementation);
        tokenImplementation = BondingToken(addresses[ETH].tokenImplementation);
        graduationManagerImplementation = GraduationManager(addresses[ETH].graduationManagerImplementation);

        protocolTreasury = addresses[ETH].protocolTreasury;
        feeRecipient = addresses[ETH].feeRecipient;
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

    function _deployContracts(uint256 fee) internal {
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

            addresses[chainIds[i]].curveFactory = address(
                new CurveFactory(
                    address(curveImplementation),
                    addresses[chainIds[i]].tokenImplementation,
                    addresses[chainIds[i]].vestingImplementation,
                    addresses[chainIds[i]].graduationManagerImplementation,
                    addresses[chainIds[i]].protocolTreasury,
                    fee
                )
            );
            vm.label(addresses[chainIds[i]].curveFactory, "CurveFactory");
        }
    }

    function _setTokens() internal {
        // Mainnet tokens
        tokens[ETH][WBTC_KEY] = CHAIN_1_WBTC;
        tokens[ETH][DAI_KEY] = CHAIN_1_DAI;
        tokens[ETH][USDC_KEY] = CHAIN_1_USDC;
        tokens[ETH][WETH_KEY] = CHAIN_1_WETH;

        // Optimism tokens
        tokens[OP][DAI_KEY] = CHAIN_10_DAI;
        tokens[OP][USDC_KEY] = CHAIN_10_USDC;
        tokens[OP][WETH_KEY] = CHAIN_10_WETH;

        // Base tokens
        tokens[BASE][DAI_KEY] = CHAIN_8453_DAI;
        tokens[BASE][USDC_KEY] = CHAIN_8453_USDC;
        tokens[BASE][WETH_KEY] = CHAIN_8453_WETH;
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
        for (uint256 i; i < tokenKeys.length; i++) {
            for (uint256 j; j < chainIds.length; j++) {
                address token = tokens[chainIds[j]][tokenKeys[i]];
                if (token != address(0)) {
                    uint256 decimals = IERC20Metadata(token).decimals();
                    deal(token, curveCreator, amount * (10 ** decimals));
                    deal(token, alice, amount * (10 ** decimals));
                    deal(token, bob, amount * (10 ** decimals));
                    deal(token, eve, amount * (10 ** decimals));
                }
            }
        }
    }
}
