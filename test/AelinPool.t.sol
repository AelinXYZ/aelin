// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import {AelinPool} from "../contracts/AelinPool.sol";

contract ContractTest is DSTest {

    AelinPool public pool;

    function setUp() public {
        pool = new AelinPool();
    }

    function testExample() public {
        emit log_address(pool.purchaseToken());
    }
}
