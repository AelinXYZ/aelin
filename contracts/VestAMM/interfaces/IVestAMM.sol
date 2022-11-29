// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";

interface IVestAMM {
    struct VestingSchedule {
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
    }

    enum Deallocation {
        None,
        Proportional,
        Laminar
    }

    // assume 50/50 to deposit ratio to start
    struct AMMData {
        address ammContract; // could be null if no liquidity yet
        address quoteAsset;
        address baseAsset;
        uint256 baseAssetAmount;
        uint256 depositorShare; // 0 to 100. Defaults to 50
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

    struct DepositToken {
        address depositToken;
        uint256 amount;
    }

    struct DealAccess {
        bytes32 merkleRoot;
        string ipfsHash;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        AelinAllowList.InitData allowListInit;
    }

    event DepositPoolToken(address indexed baseAsset, address indexed depositor, uint256 baseAssetAmount);

    event NewVestAMM(AMMData ammData, LiquidityLaunch liquidityLaunch, DealAccess dealAccess);

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);
}
