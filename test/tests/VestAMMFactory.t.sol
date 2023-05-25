// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMDealFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import "contracts/VestAMM/AelinLibraryList.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";

contract VestAMMFactoryTest is AelinVestAMMTest {
    function testVestAMMFactory() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibraryAddress);

        assertTrue(libraryList.libraryList(sushiLibraryAddress));

        VestAMMDealFactory factory = new VestAMMDealFactory(address(libraryList));

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), aelinToken, daiToken, sushiLibraryAddress, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        factory.createVestAMM(info, dealAccess);
    }
}
