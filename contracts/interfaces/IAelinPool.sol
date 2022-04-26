// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinPool {
    struct PoolData {
        string name;
        string symbol;
        uint256 purchaseTokenCap;
        address purchaseToken;
        uint256 duration;
        uint256 sponsorFee;
        uint256 purchaseDuration;
        address[] allowListAddresses;
        uint256[] allowListAmounts;
    }
}
