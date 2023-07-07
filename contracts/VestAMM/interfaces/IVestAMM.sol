// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";
import "./IVestAMMLibrary.sol";

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
        address singleHolder;
        uint256 totalSingleTokens;
        bool finalizedDeposit;
        bool isLiquid;
    }

    struct LPVestingSchedule {
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        uint256 totalBaseTokens;
        // TODO add validation this is set to 0
        uint256 totalLPTokens;
        bool finalizedDeposit;
        uint8 investorLPShare; // 0 - 100
    }

    // assume 50/50 to deposit ratio to start
    struct AmmData {
        address ammLibrary; // could be null if no liquidity yet
        address investmentToken;
        address baseToken;
    }

    struct DepositData {
        address lpToken;
        uint256 lpTokenAmount;
        uint256 lpDepositTime;
    }

    struct DeployPool {
        uint256 investmentTokenAmount;
        uint256 baseTokenAmount;
    }

    struct AddLiquidity {
        uint256 investmentTokenAmount;
        uint256 baseTokenAmount;
    }

    struct VAmmInfo {
        string name;
        string symbol;
        AmmData ammData;
        bool hasLaunchPhase;
        // TODO use this as a slippage parameter when the pool already exists
        uint256 investmentPerBase;
        uint256 depositWindow;
        uint256 lpFundingWindow;
        address mainHolder;
        LPVestingSchedule lpVestingSchedule;
        SingleVestingSchedule[] singleVestingSchedules;
        // NOTE: if hasLaunchPhase is true, then there must be a amm pool identifier we can use.
        // In most cases, the poolAddress will be enough, but some times (balancer) we need to use the poolId
        address poolAddress;
        bytes32 poolId;
        // If hasLaunchPhase is true, then we need all data needed to create a new pool
        IVestAMMLibrary.CreateNewPool newPoolData;
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
        uint8 singleRewardIndex;
        address token;
        uint256 amount;
    }

    struct RemoveSingle {
        uint8 singleRewardIndex;
    }

    event MultiRewardsCreated(address indexed rewardsContract);

    event AcceptVestDeal(address indexed depositor, uint256 depositTokenAmount, uint8 vestingScheduleIndex);

    event SingleRewardDeposited(
        address indexed holder,
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

    event SingleDepositComplete(address indexed token, uint8 singleRewardIndex);

    event BaseDeposited(address indexed token, address indexed depositor, uint256 amount, uint256 totalAmount);

    event DepositComplete(uint256 depositExpiry, uint256 lpFundingExpiry);

    event ClaimedToken(
        address indexed lpToken,
        address indexed owner,
        uint256 claimableAmount,
        ClaimType claimType,
        uint256 singleRewardsIndex
    );

    event SingleRemoved(uint8 singleIndex, address indexed token, uint256 tokenTotal, uint256 singleHolderRefund);
}
