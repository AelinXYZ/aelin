// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinERC721 {
    struct TokenDetails {
        uint256 share;
        uint256 lastClaimedAt;
        uint256 vestingIndex;
    }

    event SetAelinERC721(string name, string symbol);
}
