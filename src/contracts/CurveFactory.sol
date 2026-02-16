// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ICurveFactory } from "../interfaces/ICurveFactory.sol";

// OpenZeppelin Contracts
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CurveFactory
/// @notice Factory for creating Curve contracts
/// @author balanced-tree
contract CurveFactory is ICurveFactory {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  using Math for uint256;
}