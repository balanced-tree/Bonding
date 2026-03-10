// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

abstract contract Constants {
    // Chains
    string public constant ETHEREUM_KEY = "Ethereum";
    string public constant OPTIMISM_KEY = "Optimism";
    string public constant BASE_KEY = "Base";

    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;

    uint256 public constant ETH_BLOCK = 21_929_476;
    uint256 public constant OP_BLOCK = 132_481_010;
    uint256 public constant BASE_BLOCK = 26_885_730;

    // Amounts
    uint256 public constant SMALL = 1 ether;
    uint256 public constant MEDIUM = 5 ether;
    uint256 public constant LARGE = 20 ether;
    uint256 public constant EXTRA_LARGE = 100 ether;

    // RPC 
    string public constant ETHEREUM_RPC_URL_KEY = "ETHEREUM_RPC_URL";
    string public constant OPTIMISM_RPC_URL_KEY = "OPTIMISM_RPC_URL";
    string public constant BASE_RPC_URL_KEY = "BASE_RPC_URL";

    // Tokens
    string public constant DAI_KEY = "DAI";
    string public constant USDC_KEY = "USDC";
    string public constant WETH_KEY = "WETH";
    string public constant WBTC_KEY = "WBTC";

    address public constant CHAIN_1_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant CHAIN_1_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CHAIN_1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant CHAIN_1_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant CHAIN_10_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant CHAIN_10_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant CHAIN_10_WETH = 0x4200000000000000000000000000000000000006;

    address public constant CHAIN_8453_DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant CHAIN_8453_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant CHAIN_8453_WETH = 0x4200000000000000000000000000000000000006;

}