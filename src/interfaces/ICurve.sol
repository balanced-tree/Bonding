// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ICurve
/// @notice Interface for the bonding curve contract
interface ICurve {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensBought(address indexed buyer, uint256 collateralIn, uint256 tokensOut, uint256 fee);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 collateralOut, uint256 fee);
    event CurveGraduated(uint256 totalCollateral, uint256 totalSupply);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ALREADY_GRADUATED();
    error SLIPPAGE_EXCEEDED();
    error INVALID_AMOUNT();
    error EXCEEDS_MAX_PER_TX();
    error ZERO_TOKENS_OUT();
    error ZERO_COLLATERAL_OUT();
    error NOT_GRADUATED();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function buy(uint256 collateralAmount, uint256 minTokensOut) external returns (uint256 tokensOut);
    function sell(uint256 tokenAmount, uint256 minCollateralOut) external returns (uint256 collateralOut);
    function graduate() external;
    function getPrice() external view returns (uint256);
    function getBuyQuote(uint256 collateralAmount) external view returns (uint256 tokensOut);
    function getSellQuote(uint256 tokenAmount) external view returns (uint256 collateralOut);
}
