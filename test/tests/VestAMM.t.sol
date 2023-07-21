// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/libraries/MerkleTree.sol";

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import {VestAMM} from "contracts/VestAMM/VestAMM.sol";

contract VestAMMTest is AelinVestAMMTest {}
