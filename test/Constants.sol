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

    

}