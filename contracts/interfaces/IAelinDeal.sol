// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinDeal {
    struct DealData {
			string name,
			string symbol,
			address underlyingDealToken,
			uint256 underlyingDealTokenTotal,
			uint256 vestingPeriod,
			uint256 vestingCliff,
			uint256 proRataRedemptionPeriod,
			uint256 openRedemptionPeriod,
			address holder,
			uint256 maxDealTotalSupply,
			uint256 holderFundingDuration,
			address aelinRewardsAddress
    }
}
