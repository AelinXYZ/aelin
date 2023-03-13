// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";

interface IVestAMM {
    enum Deallocation {
        None,
        Proportional
    }

    enum ClaimType {
        Single,
        Base
    }

    struct VestingSchedule {
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        Deallocation deallocation;
        uint256 investorShare; // 0 to 100
        uint256 totalHolderTokens;
    }

    // assume 50/50 to deposit ratio to start
    struct AmmData {
        address ammLibrary; // could be null if no liquidity yet
        address investmentToken;
        address baseAsset;
        uint256 baseAssetAmount;
    }

    struct FundingLimits {
        uint256 lower;
        uint256 upper;
    }

    struct VAmmInfo {
        bool hasLaunchPhase;
        bool isPriceFixed;
        uint256 investmentPerBase;
        uint256 depositWindow;
        uint256 lpFundingWindow;
        address mainHolder;
        VestingSchedule[] vestingSchedules;
        FundingLimits fundingLimits;
    }

    struct MigrationRules {
        bool canMigrate;
        uint256 rewardPerQuote;
    }

    struct SingleRewardConfig {
        address rewardToken;
        uint256 rewardPerQuote;
        uint256 rewardTokenTotal;
        VestingSchedule vestingData;
        MigrationRules migrationRules; // ??
        address singleHolder;
    }

    struct DealAccess {
        bytes32 merkleRoot;
        string ipfsHash;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        AelinAllowList.InitData allowListInit;
    }

    struct DepositToken {
        address token;
        uint256 amount;
        uint8 singleRewardIndex;
    }

    event AcceptVestDeal(address indexed depositor, uint256 depositTokenAmount);

    event TokenDeposited(address token, uint256 amount);

    event NewVestAMM(AmmData ammData, VAmmInfo vAMMInfo, SingleRewardConfig[] singleRewards, DealAccess dealAccess);

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);

    event TokenDepositComplete(address indexed token);

    event DepositComplete(uint256 depositExpiry, uint256 lpFundingExpiry);

    event ClaimedToken(address indexed lpToken, address indexed owner, uint256 claimableAmount, ClaimType claimType);
}
