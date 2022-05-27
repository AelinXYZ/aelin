// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinUpFrontDeal {
    struct UpFrontDealData {
        string name;
        string symbol;
        //uint256 purchaseTokenCap; No longer need when selling a quantity of tokens at a set price
        address purchaseToken;
        uint256 duration;
        //uint256 sponsorFee; There is no sponsor for up front deals
        uint256 purchaseDuration;
        address[] allowListAddresses;
        uint256[] allowListAmounts;
        NftCollectionRules[] nftCollectionRules;
        address underlyingDealToken;
        uint256 underlyingDealTokenTotal;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        //uint256 proRataRedemptionPeriod;
        //uint256 openRedemptionPeriod;
        address holder;
        uint256 maxDealTotalSupply;
        //uint256 holderFundingDuration; Do not need with the combination of purchaseDuration and duration

        uint256 purchaseTokenPerDealToken;
        // uint256 minimumRaise; future AELIP to revert deal if not enough purchase tokens raised
        // DuctionAuctionRules[] dutchAuctionRules; future AELIP for dutch auction pricing
    }

    // collectionAddress should be unique, otherwise will override
    struct NftCollectionRules {
        // if 0, then unlimited purchase
        uint256 purchaseAmount;
        address collectionAddress;
        // if true, then `purchaseAmount` is per token
        // else `purchaseAmount` is per account regardless of the NFTs held
        bool purchaseAmountPerToken;
        // both variables below are only applicable for 1155
        uint256[] tokenIds;
        // min number of tokens required for participating
        uint256[] minTokensEligible;
    }

    struct NftPurchaseList {
        address collectionAddress;
        uint256[] tokenIds;
    }
}
