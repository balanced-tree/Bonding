// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// OpenZeppelin Contracts
import { Initializable } from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

// Contracts
import { IVesting } from "../interfaces/IVesting.sol";

abstract contract Vesting is Initializable, IVesting {

}