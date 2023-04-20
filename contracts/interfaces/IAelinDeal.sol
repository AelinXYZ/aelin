// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinDeal {
    struct DealData {
        address underlyingDealToken;
        uint256 underlyingDealTokenTotal;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        uint256 proRataRedemptionPeriod;
        uint256 openRedemptionPeriod;
        address holder;
        uint256 maxDealTotalSupply;
        uint256 holderFundingDuration;
    }

    struct Timeline {
        uint256 period;
        uint256 start;
        uint256 expiry;
    }

    event HolderSet(address indexed holder);
    event HolderAccepted(address indexed holder);
    event DealFullyFunded(
        address indexed poolAddress,
        uint256 proRataRedemptionStart,
        uint256 proRataRedemptionExpiry,
        uint256 openRedemptionStart,
        uint256 openRedemptionExpiry
    );
    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
    event WithdrawUnderlyingDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
    event ClaimedUnderlyingDealToken(
        address indexed recipient,
        uint256 indexed tokenId,
        address underlyingDealTokenAddress,
        uint256 underlyingDealTokensClaimed
    );
}
