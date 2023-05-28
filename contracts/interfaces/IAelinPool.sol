// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
        NftCollectionRules[] nftCollectionRules;
    }

    /**
     * @dev The collectionAddress should be unique, otherwise will override pre-existing storage.
     * NOTE If purchaseAmount equals zero, then unlimited purchase amounts are allowed. Additionally,
     * both the tokenIds and minTokensEligible arrays are only applicable for deals involving ERC1155
     * collections.
     */
    struct NftCollectionRules {
        uint256 purchaseAmount;
        address collectionAddress;
        // Ranges for 721s
        IdRange[] idRanges;
        // Ids and minimums for 1155s
        uint256[] tokenIds;
        uint256[] minTokensEligible;
    }

    /**
     * NOTE The range is inclusive of beginning and ending token Ids.
     */
    struct IdRange {
        uint256 begin;
        uint256 end;
    }

    struct NftPurchaseList {
        address collectionAddress;
        uint256[] tokenIds;
    }
}
