// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// OpenZeppelin Contracts
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract GraduationManager is Initializable, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;
    using Math for uint256;
}