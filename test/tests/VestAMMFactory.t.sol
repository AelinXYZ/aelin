// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";

contract VestAMMFactoryTest is AelinVestAMMTest {
    function testVestAMMFactory() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);
    }
}
