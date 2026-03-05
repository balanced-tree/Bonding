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
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }
}
