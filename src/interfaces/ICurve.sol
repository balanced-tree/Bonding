// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ICurve
/// @notice Interface for the bonding curve contract
interface ICurve {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Initialized(address indexed token, address indexed vesting, address indexed creator);
    event TokensBought(address indexed buyer, uint256 collateralIn, uint256 tokensOut, uint256 fee);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 collateralOut, uint256 fee);
    event CurveGraduated(uint256 totalCollateral, uint256 totalSupply);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_AMOUNT();
    error SLIPPAGE_EXCEEDED();
    error ALREADY_GRADUATED();
    error EXCEEDS_MAX_PER_TX();
    error ZERO_COLLATERAL_OUT();
    error ALREADY_INITIALIZED();
    error INVALID_CONFIGURATION();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Buy tokens by depositing collateral into the bonding curve
    /// @dev Transfers collateral from the caller, mints tokens, and collects a fee.
    ///      Reverts if the output falls below `minTokensOut` (slippage protection).
    /// @param collateralAmount The amount of collateral to spend
    /// @param minTokensOut The minimum acceptable tokens to receive (slippage guard)
    /// @return tokensOut The actual number of tokens minted to the buyer
    function buy(uint256 collateralAmount, uint256 minTokensOut) external returns (uint256 tokensOut);

    /// @notice Sell tokens back to the bonding curve in exchange for collateral
    /// @dev Burns the caller's tokens and transfers collateral out, minus fees.
    ///      Reverts if the output falls below `minCollateralOut` (slippage protection).
    /// @param tokenAmount The amount of tokens to sell
    /// @param minCollateralOut The minimum acceptable collateral to receive (slippage guard)
    /// @return collateralOut The actual amount of collateral returned to the seller
    function sell(uint256 tokenAmount, uint256 minCollateralOut) external returns (uint256 collateralOut);

    /// @notice Returns the current spot price of the token on the bonding curve
    /// @return The current price in collateral per token (18-decimal fixed point)
    function getPrice() external view returns (uint256);

    /// @notice Returns the address of the ERC20 token managed by this curve
    /// @return The bonding curve token address
    function getTokenAddress() external view returns (address);

    /// @notice Returns the address of the collateral token used for buys and sells
    /// @return The collateral token address
    function getCollateralAddress() external view returns (address);

    /// @notice Returns a quote for how many tokens would be received for a given collateral amount
    /// @dev Does not execute a trade; read-only preview of a buy
    /// @param collateralAmount The amount of collateral to quote
    /// @return tokensOut The estimated number of tokens that would be minted
    function getBuyQuote(uint256 collateralAmount) external view returns (uint256 tokensOut);

    /// @notice Returns a quote for how much collateral would be received for selling tokens
    /// @dev Does not execute a trade; read-only preview of a sell
    /// @param tokenAmount The amount of tokens to quote
    /// @return collateralOut The estimated collateral that would be returned
    function getSellQuote(uint256 tokenAmount) external view returns (uint256 collateralOut);

    /// @notice Graduates the bonding curve once the collateral threshold is reached
    /// @dev Triggers the graduation manager to migrate liquidity (e.g., to a DEX).
    /// Reverts if the curve has already graduated or the threshold is not met.
    function graduateCurve() external;
}
