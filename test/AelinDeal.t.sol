// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import {AelinDeal} from "../contracts/AelinDeal.sol";

contract AelinDealTest is DSTest {

    AelinDeal public deal;

    function setUp() public {
        deal = new AelinDeal();
    }

    function testExample() public {
        emit log_address(deal.underlyingDealToken());
    }
}
