// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ICurve } from "../interfaces/ICurve.sol";

// OpenZeppelin Contracts
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// OpenZeppelin Upgradeable
import { ERC20Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract Curve is ICurve {
    using SafeERC20 for IERC20;
    using Math for uint256;

}