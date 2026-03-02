// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IBondingCurveToken
/// @notice Interface for the ERC20 token deployed per bonding curve
interface IBondingCurveToken {
    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address minter_) external;
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
