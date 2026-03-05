// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title BondingToken
/// @notice ERC20 token deployed as an EIP-1167 clone per bonding curve.
///         Only the associated Curve contract can mint and burn.
contract BondingToken is Initializable, ERC20Upgradeable {
    address public minter;
    uint8 private _tokenDecimals;

    error ONLY_MINTER();
    error INVALID_MINTER();

    modifier onlyMinter() {
        if (msg.sender != minter) revert ONLY_MINTER();
        _;
    }

    /// @dev Locks the implementation contract from being initialized
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address minter_
    ) external initializer {
        if (minter_ == address(0)) revert INVALID_MINTER();
        __ERC20_init(name_, symbol_);
        _tokenDecimals = decimals_;
        minter = minter_;
    }
    
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints tokens to an address
    /// @dev Only the minter can mint tokens
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /// @notice Burns tokens from an address
    /// @dev Only the minter can burn tokens
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the number of decimals used to get its user representation
    /// @dev Overrides the ERC20 decimals function
    /// @return The number of decimals
    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }
}
