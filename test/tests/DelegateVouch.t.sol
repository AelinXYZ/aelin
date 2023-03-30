// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {DelegateVouch} from "contracts/DelegateVouch.sol";

contract DelegateVouchTest is Test {
    address public aelinCouncil = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    DelegateVouch public delegateVouchAddress;

    event AddDelegateVouch(address indexed delegate);
    event RemoveDelegateVouch(address indexed delegate);
    Vm vm = Vm(address(0));
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/EW9N4oDCQJ58k_9wF-wG8pkq7amdPnqD");
        delegateVouchAddress = new DelegateVouch(aelinCouncil);
    }

    /*//////////////////////////////////////////////////////////////
                        addDelegateVouch
    //////////////////////////////////////////////////////////////*/

    function testFuzzAddDelegateVouch(address delegate) public {
        vm.prank(aelinCouncil);
        vm.expectEmit(false, false, false, false, address(delegateVouchAddress));
        emit AddDelegateVouch(delegate);
        DelegateVouch(delegateVouchAddress).addDelegateVouch(delegate);
        assertEq(DelegateVouch(delegateVouchAddress).isDelegate(delegate), true);
    }

    function testFuzzAddDelegateVouchOnlyOwner(address delegate, address caller) public {
        vm.assume(caller != aelinCouncil);
        vm.prank(caller);
        vm.expectRevert("Only the contract owner may perform this action");
        DelegateVouch(delegateVouchAddress).addDelegateVouch(delegate);
    }

    /*//////////////////////////////////////////////////////////////
                        removeDelegateVouch
    //////////////////////////////////////////////////////////////*/

    function testFuzzRemoveDelegateVouch(address delegate) public {
        vm.prank(aelinCouncil);
        vm.expectEmit(false, false, false, false, address(delegateVouchAddress));
        emit RemoveDelegateVouch(delegate);
        DelegateVouch(delegateVouchAddress).removeDelegateVouch(delegate);
        assertEq(DelegateVouch(delegateVouchAddress).isDelegate(delegate), false);
    }

    function testFuzzRemoveDelegateVouchOnlyOwner(address delegate, address caller) public {
        vm.assume(caller != aelinCouncil);
        vm.prank(caller);
        vm.expectRevert("Only the contract owner may perform this action");
        DelegateVouch(delegateVouchAddress).removeDelegateVouch(delegate);
    }
}
