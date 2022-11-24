// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinVestingToken {
    struct TokenDetails {
        uint256 share;
        uint256 lastClaimedAt;
    }

    event VestingTokenMinted(address indexed user, uint256 indexed tokenId, uint256 amount, uint256 lastClaimedAt);
}
