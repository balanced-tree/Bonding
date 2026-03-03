// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IBondingCurveToken
/// @notice Interface for the ERC20 token deployed per bonding curve
interface IBondingCurveToken {
    /// @notice Initializes the token clone with metadata and authorized minter
    /// @dev Called once after clone deployment. Sets the token name, symbol, decimals,
    ///      and the sole address authorized to mint and burn.
    /// @param name_ The token name (e.g., "My Bonding Token")
    /// @param symbol_ The token symbol (e.g., "MBT")
    /// @param decimals_ The number of decimals (typically 18)
    /// @param minter_ The address authorized to mint and burn (usually the Curve contract)
    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address minter_) external;

    /// @notice Mints new tokens to a recipient
    /// @dev Only callable by the authorized minter (the Curve contract)
    /// @param to The address to receive the minted tokens
    /// @param amount The number of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burns tokens from a holder
    /// @dev Only callable by the authorized minter (the Curve contract)
    /// @param from The address whose tokens will be burned
    /// @param amount The number of tokens to burn
    function burn(address from, uint256 amount) external;

    /// @notice Returns the total supply of the token
    /// @return The current total supply
    function totalSupply() external view returns (uint256);

    /// @notice Returns the token balance of a given account
    /// @param account The address to query
    /// @return The token balance of the account
    function balanceOf(address account) external view returns (uint256);
}
