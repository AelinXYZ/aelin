// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinDealTokenFactory} from "contracts/AelinDealTokenFactory.sol";
import {AelinDealToken} from "contracts/AelinDealToken.sol";
import {IAelinDealToken} from "contracts/interfaces/IAelinDealToken.sol";

contract AelinDealTokenFactoryTest is Test {
    AelinDealTokenFactory public dealTokenFactory;
    AelinDealToken public testDealToken;

    function setUp() public {
        testDealToken = new AelinDealToken();
        dealTokenFactory = new AelinDealTokenFactory(address(testDealToken));
        assertEq(dealTokenFactory.AELIN_DEAL_TOKEN_LOGIC(), address(testDealToken));
    }

    function testFuzzCreateDealToken(uint256 amount) public {
        vm.assume(amount < 1e27);
        IAelinDealToken.DealTokenData memory dealTokenData;
        dealTokenData = IAelinDealToken.DealTokenData({name: "DEAL-TOKEN", symbol: "DTKN", decimals: 18, amount: amount});
        address dealTokenAddress = dealTokenFactory.createDealToken(dealTokenData);

        assertEq(AelinDealToken(dealTokenAddress).name(), "DEAL-TOKEN");
        assertEq(AelinDealToken(dealTokenAddress).symbol(), "DTKN");
        assertEq(AelinDealToken(dealTokenAddress).decimals(), 18);
        assertEq(AelinDealToken(dealTokenAddress).totalSupply(), amount);
    }
}
