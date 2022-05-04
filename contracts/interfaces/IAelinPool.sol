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
        NftData[] nftData;
    }

    // collectionAddress should be unique, otherwise will override
    struct NftData {
        // if 0, then unlimited purchase
        uint256 purchaseAmount;
        address collectionAddress;
        // if true, then `purchaseAmount` is per token
        // else `purchaseAmount` is per account regardless of the NFTs held
        bool purchaseAmountPerToken;
        // can add tokenId for 1155, but cannot be 0 because there are many 721s with tokenid 0
    }
}
