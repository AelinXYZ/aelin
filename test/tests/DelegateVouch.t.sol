// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {DelegateVouch} from "contracts/DelegateVouch.sol";

contract DelegateVouchTest is Test {
    address public aelinCouncil = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    DelegateVouch public delegateVouchAddress;

    event AddDelegateVouch(address indexed delegate);
    event RemoveDelegateVouch(address indexed delegate);

    function setUp() public {
        delegateVouchAddress = new DelegateVouch(aelinCouncil);
    }

    /*//////////////////////////////////////////////////////////////
                        addDelegateVouch
    //////////////////////////////////////////////////////////////*/
    // Revert scenario
    function testFuzz_addDelegateVouch_RevertIf_NotOwner(address delegate, address caller) public {
        vm.assume(caller != aelinCouncil);

        vm.prank(caller);
        vm.expectRevert("Only the contract owner may perform this action");
        DelegateVouch(delegateVouchAddress).addDelegateVouch(delegate);
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_addDelegateVouch(address delegate) public {
        vm.prank(aelinCouncil);

        vm.expectEmit(true, true, true, true, address(delegateVouchAddress));
        emit AddDelegateVouch(delegate);
        DelegateVouch(delegateVouchAddress).addDelegateVouch(delegate);

        assertTrue(DelegateVouch(delegateVouchAddress).isDelegate(delegate), "Should be added to isDelegate");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        removeDelegateVouch
    //////////////////////////////////////////////////////////////*/
    // Revert scenario
    function testFuzz_removeDelegateVouch_RevertIf_NotOwner(address delegate, address caller) public {
        vm.assume(caller != aelinCouncil);

        vm.prank(caller);
        vm.expectRevert("Only the contract owner may perform this action");
        DelegateVouch(delegateVouchAddress).removeDelegateVouch(delegate);
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_removeDelegateVouch(address delegate) public {
        vm.prank(aelinCouncil);
        vm.expectEmit(true, true, true, true, address(delegateVouchAddress));
        emit RemoveDelegateVouch(delegate);
        DelegateVouch(delegateVouchAddress).removeDelegateVouch(delegate);

        assertFalse(DelegateVouch(delegateVouchAddress).isDelegate(delegate), "Should be removed from isDelegate");
        vm.stopPrank();
    }
}
