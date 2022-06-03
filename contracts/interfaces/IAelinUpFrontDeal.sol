// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IAelinPool} from "./IAelinPool.sol";

interface IAelinUpFrontDeal {
    struct UpFrontDeal {
        string name;
        string symbol;
        address purchaseToken;
        address sponsor;
        uint256 sponsorFee;
        uint256 purchaseDuration;
        address[] allowListAddresses;
        uint256[] allowListAmounts;
        IAelinPool.NftCollectionRules[] nftCollectionRules;
        address underlyingDealToken;
        uint256 underlyingDealTokenTotal;
        uint256 purchaseTokenPerDealToken;
        uint256 purchaseRaiseMinimum;
        uint256 purchaseTokenCap;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        address holder;
    }

    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );

    event CreateUpFrontDeal(
        address indexed poolAddress,
        string name,
        string symbol,
        uint256 purchaseTokenCap,
        address indexed purchaseToken,
        uint256 sponsorFee,
        uint256 purchaseDuration,
        address indexed sponsor,
        bool hasAllowList
    );

    event AllowlistAddress(address[] indexed allowListAddresses, uint256[] allowlistAmounts);

    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount, bool purchaseAmountPerToken);

    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        bool purchaseAmountPerToken,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );
}
