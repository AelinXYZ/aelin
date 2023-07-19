// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/AelinLibraryList.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/libraries/MerkleTree.sol";
import "contracts/VestAMM/libraries/AmmIntegration/SushiVestAMM.sol";

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMDealFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import {VestAMM} from "contracts/VestAMM/VestAMM.sol";

contract VestAMMTest is AelinVestAMMTest {
    /// @dev All just needs to be re-done, easier to start from scratch
}
