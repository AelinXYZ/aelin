// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinUnderlyingDealToken {
    struct UnderlyingDealTokenConfig {
        bool isFundingDeal;
        string name;
        string symbol;
        address account;
        uint256 mintAmount;
    }
}
