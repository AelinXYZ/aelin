// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

contract AelinTestUtils {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    uint256 constant BASE = 100 * 10 ** 18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 constant AELIN_FEE = 2 * 10 ** 18;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);
    address user2 = address(0x1338);
    address user3 = address(0x1339);
    address user4 = address(0x1340);
}
