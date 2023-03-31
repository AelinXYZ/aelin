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
        LP
    }

    struct VestingSchedule {
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
    }

    // Protocol ABC has multiple vesting schedules for the LP tokens (LPVestingSchedule)
    // schedule 1 example
    // uint256 vestingPeriod = 3 months;
    // uint256 vestingCliffPeriod = 3 months;
    // uint8 investorLPShare = 50;
    // uint8 totalHolderTokens = 100 * 1e18 (100 ABC tokens)
    // schedule 2 example
    // uint256 vestingPeriod = 6 months;
    // uint256 vestingCliffPeriod = 6 months;
    // uint8 investorLPShare = 75;
    // uint8 totalHolderTokens = 200 * 1e18 (200 ABC tokens)
    // schedule 3 example
    // uint256 vestingPeriod = 12 months;
    // uint256 vestingCliffPeriod = 12 months;
    // uint8 investorLPShare = 100;
    // uint8 totalHolderTokens = 300 * 1e18 (300 ABC tokens)

    // we have multiple single rewards programs each with different vesting schedules (SingleVestingSchedule)
    // reward 1 example is OP tokens
    // vestingScheduleIndex = 1 gets nothing because they do not want to incentivize short term lockups

    // NOTE OP is vesting 50% faster than the LP tokens
    // uint256 vestingPeriod = 3 months;
    // uint256 vestingCliffPeriod = 3 months;
    // uint8 totalSingleTokens = 10 * 1e18 (10 OP tokens)
    // uint 8 vestingScheduleIndex = 2;

    // uint256 vestingPeriod = 3 months;
    // uint256 vestingCliffPeriod = 3 months;
    // uint8 totalSingleTokens = 20 * 1e18 (20 OP tokens)
    // uint 8 vestingScheduleIndex = 3;

    // the extra logic piece that goes in the contracts is for schedule 2 there are 200 ABC tokens
    // the pricing of these is set up front when the vAMM is created either by passing in the price or
    // reading it from an existing AMM
    // so you might have 2 sUSD/ ABC in which case the second bucket will have a maximum of 400 sUSD
    // if there is more than 400 everyone gets dellocated. if there is less than 400 the protocol will get
    // some of their ABC tokens back since they are unmatched
    // if the protocol raises 400 sUSD then all 10 OP tokens are given out to holders
    // if the protoocol only raises 200 sUSD then only 5 of the OP tokens are given to holders
    // the other 5 OP tokens are claimable by the single rewards holder

    // used for each reward to be claimed or the LP tokens
    struct LPVestingSchedule {
        VestingSchedule vestingSchedule;
        uint8 investorLPShare; // 0 - 100
        uint256 totalHolderTokens;
    }
    // used for each reward to be claimed or the LP tokens
    struct SingleVestingSchedule {
        VestingSchedule vestingSchedule;
        uint8 vestingScheduleIndex;
        uint256 totalSingleTokens;
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
        Deallocation deallocation;
        LPVestingSchedule[] vestingSchedules;
        FundingLimits fundingLimits;
    }

    struct MigrationRules {
        bool canMigrate;
        uint256 rewardPerQuote;
    }

    struct SingleRewardConfig {
        address rewardToken;
        bool finalizedDeposit;
        uint256 amountDeposited;
        uint256 rewardPerQuote;
        uint256 rewardTokenTotal;
        VestingSchedule vestingData;
        MigrationRules migrationRules; // ??
        address singleHolder;
        uint256 amountClaimed;
    }

    struct DealAccess {
        bytes32 merkleRoot;
        string ipfsHash;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        AelinAllowList.InitData allowListInit;
    }

    struct DepositToken {
        uint8 singleRewardIndex;
        address token;
        uint256 amount;
    }

    struct RemoveSingle {
        address token;
        address holder;
    }

    event AcceptVestDeal(address indexed depositor, uint256 depositTokenAmount, uint8 vestingScheduleIndex);

    event TokenDeposited(address token, uint256 amount);

    event NewVestAMM(AmmData ammData, VAmmInfo vAMMInfo, SingleRewardConfig[] singleRewards, DealAccess dealAccess);

    event SetHolder(address indexed holder);

    event Withdraw(address indexed depositor, uint256 amountDeposited);

    event SentFees(address indexed token, uint256 amount);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);

    event SingleDepositComplete(address indexed token, uint8 singleRewardIndex);

    event DepositComplete(uint256 depositExpiry, uint256 lpFundingExpiry);

    event ClaimedToken(address indexed lpToken, address indexed owner, uint256 claimableAmount, ClaimType claimType);

    event SingleRemoved(
        uint8 index,
        address indexed token,
        uint256 tokenTotal,
        uint256 mainHolderRefund,
        uint256 singleHolderRefund
    );
}
