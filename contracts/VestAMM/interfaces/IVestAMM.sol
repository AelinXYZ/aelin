// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

interface IVestAMM {
    /// @dev check where these are used?
    enum Deallocation {
        None,
        Proportional
    }

    enum ClaimType {
        Single,
        LP
    }

    //////////////
    // vAMMInfo //
    //////////////

    struct VAmmInfo {
        string name;
        string symbol;
        AmmData ammData; // investment and base toke
        bool hasLaunchPhase;
        uint256 investmentPerBase; // TODO use this as a slippage parameter when the pool already exists
        uint256 depositWindow;
        uint256 lpFundingWindow;
        address mainHolder; // The DAO creating the VestAMM
        LPVestingSchedule lpVestingSchedule;
        SingleVestingSchedule[] singleVestingSchedules;
        // NOTE: if hasLaunchPhase is true, then there must be a amm pool identifier we can use.
        // In most cases, the poolAddress will be enough, but some times (balancer) we need to use the poolId
        address poolAddress;
        bytes32 poolId;
    }

    // assume 50/50 to deposit ratio to start
    struct AmmData {
        address investmentToken;
        address baseToken;
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

    struct SingleVestingSchedule {
        address rewardToken;
        address singleHolder;
        uint256 totalSingleTokens;
        bool finalizedDeposit;
        bool isLiquid;
    }

    ////////////////
    // DealAccess //
    ////////////////

    struct DealAccess {
        bytes32 merkleRoot;
        string ipfsHash;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        AelinAllowList.InitData allowListInit;
    }

    struct DepositData {
        address lpToken;
        uint256 lpTokenAmount;
        uint256 lpDepositTime;
    }

    ///////////////
    // Liquidity //
    ///////////////

    struct AddLiquidity {
        address poolAddress;
        uint256[] tokensAmtsIn;
        address[] tokens;
    }

    struct RemoveLiquidity {
        address poolAddress;
        address lpToken;
        uint256 lpTokenAmtIn;
        address[] tokens;
    }

    //////////////
    // Unsorted //
    //////////////

    /*

    struct DeployPool {
        uint256 investmentTokenAmount;
        uint256 baseTokenAmount;
    }

    struct AddLiquidity {
        uint256 investmentTokenAmount;
        uint256 baseTokenAmount;
    }

    struct MigrationRules {
        bool canMigrate;
        uint256 rewardPerQuote;
    }
    */

    struct DepositToken {
        uint8 singleRewardIndex;
        address token;
        uint256 amount;
    }

    /// @dev either delete or expand, a struct with only one variable is confusing
    struct RemoveSingle {
        uint8 singleRewardIndex;
    }

    ////////////
    // Events //
    ////////////

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
        uint8 singleRewardsIndex
    );

    event SingleRemoved(uint8 singleIndex, address indexed token, uint256 tokenTotal, uint256 singleHolderRefund);
}
