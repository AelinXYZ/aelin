// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IAelinPool} from "./IAelinPool.sol";

interface IAelinVLP {
    struct VestingSchedule {
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
    }

    enum Deallocation {
        NoneAndCapped,
        Proportional,
        Laminar
    }

    // TBD access rules here or maybe not
    struct AMMData {
        address ammContract;
        address quoteAsset;
        address baseAsset;
        uint256 baseAssetWeight; // NOTE only using 2 assets to start probably so can just do 100-this value for the quote asset weight
        uint256 investorShare;
        VestingSchedule vestingData;
    }

    struct LiquidityLaunch {
        bool hasLaunchPhase;
        uint256 initialQuotePerBase;
        uint256 depositWindow;
        uint256 lpFundingWindow;
        Deallocation deallocation;
    }

    struct MigrationRules {
        bool canMigrate;
        uint256 rewardPerQuote;
    }

    struct SingleRewardConfig {
        address rewardToken;
        uint256 rewardPerQuote;
        VestingSchedule vestingData;
        MigrationRules migrationRules;
    }

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);
}
