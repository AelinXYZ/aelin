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

    struct SingleVestingSchedule {
        address rewardToken;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        address singleHolder;
        uint256 totalSingleTokens;
        uint256 claimed;
        bool finalizedDeposit;
    }

    struct LPVestingSchedule {
        SingleVestingSchedule[] singleVestingSchedules;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        uint256 totalBaseTokens;
        uint256 claimed;
        bool finalizedDeposit;
        uint8 investorLPShare; // 0 - 100
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
        LPVestingSchedule[] lpVestingSchedules;
        FundingLimits fundingLimits;
    }

    struct MigrationRules {
        bool canMigrate;
        uint256 rewardPerQuote;
    }

    struct DealAccess {
        bytes32 merkleRoot;
        string ipfsHash;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        AelinAllowList.InitData allowListInit;
    }

    struct DepositToken {
        uint8 lpScheduleIndex;
        uint8 singleRewardIndex;
        address token;
        uint256 amount;
    }

    struct RemoveSingle {
        uint8 lpScheduleIndex;
        uint8 singleRewardIndex;
        address token;
    }

    event AcceptVestDeal(address indexed depositor, uint256 depositTokenAmount, uint8 vestingScheduleIndex);

    event SingleRewardDeposited(
        address indexed holder,
        uint8 vestingScheduleIndex,
        uint8 singleRewardIndex,
        address indexed token,
        uint256 amountPostTransfer
    );

    event NewVestAMM(AmmData ammData, VAmmInfo vAMMInfo, DealAccess dealAccess);

    event SetHolder(address indexed holder);

    event Withdraw(address indexed depositor, uint256 amountDeposited);

    event SentFees(address indexed token, uint256 amount);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);

    event SingleDepositComplete(address indexed token, uint8 vestingScheduleIndex, uint8 singleRewardIndex);

    event DepositComplete(uint256 depositExpiry, uint256 lpFundingExpiry);

    event ClaimedToken(
        address indexed lpToken,
        address indexed owner,
        uint256 claimableAmount,
        ClaimType claimType,
        uint8 vestingScheduleIndex,
        uint8 singleRewardsIndex
    );

    event SingleRemoved(
        uint8 singleIndex,
        uint8 lpIndex,
        address indexed token,
        uint256 tokenTotal,
        uint256 mainHolderRefund,
        uint256 singleHolderRefund
    );
}
