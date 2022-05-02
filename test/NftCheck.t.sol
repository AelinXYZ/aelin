// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import "../contracts/libraries/NftCheck.sol";

contract NftCheckTest is DSTest {
    // add `--fork-url` before testing

    // 721
    address private constant bayc = address(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    address private constant mayc = address(0x60E4d786628Fea6478F785A6d7e704777c86a7c6);
    address private constant azuki = address(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    // 1155
    address private constant eight = address(0x36d30B3b85255473D27dd0F7fD8F35e36a9d6F06);
    address private constant adidas = address(0x28472a58A490c5e09A238847F66A68a47cC76f0f);
    address private constant rtfkt = address(0x86825dFCa7A6224cfBd2DA48e85DF2fc3Aa7C4B1);

    function setUp() public {}

    function test721() public {
        assertTrue(NftCheck.supports721(bayc));
        assertTrue(NftCheck.supports721(mayc));
        assertTrue(NftCheck.supports721(azuki));
    }

    function test1155() public {
        assertTrue((NftCheck.supports1155(eight)));
        assertTrue((NftCheck.supports1155(adidas)));
        assertTrue((NftCheck.supports1155(rtfkt)));
    }
    
    function testFail1155() public {
        assertTrue((NftCheck.supports1155(bayc)));
        assertTrue((NftCheck.supports1155(mayc)));
        assertTrue((NftCheck.supports1155(azuki)));
    }

    function testFail721() public {
        assertTrue(NftCheck.supports721(eight));
        assertTrue(NftCheck.supports721(adidas));
        assertTrue(NftCheck.supports721(rtfkt));
    }
}