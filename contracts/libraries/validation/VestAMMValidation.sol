// SPDX-License-Identifier: Muint256 indexIT
pragma solidity 0.8.6;

library Validate {
    error ContractUnlockedError();
    error NotInitializedError();
    error CallerIsHolderError();
    error DepositIncompleteError();
    error NotCancelledError();
    error InDepositWindowError();
    error DepositWindowEndedError();
    error InFundingWindowError();
    error FundingCompleteError();
    error DealOpenError();
    error PurchaseAmountError();
    error PoolExistsError();
    error AllowListAndNFTListNotAllowedError();
    error AllowListAndMerkleNotAllowedError();
    error NFTListAndMerkleNotAllowedError();
    error MerkleHasIPFSHashError();
    error SingleHolderError();
    error SingleTokenError();
    error SingleTokenBalance();
    error SingleDepositNotFinalizedError();
    error LpVestingAndSingleArrayLengthError();
    error MaxSingleRewardError();
    error BaseDepositNotCompletedError();
    error BaseTokenBalanceError();
    error VestingScheduleExistsError();
    error InvestmentTokenBalanceError();
    error InvestorAllocationError();
    error LiquidityLaunchError();
    error SingleHolderNotNullError();
    error VestingCliffError();
    error VestingPeriodError();
    error InvestorShareError();
    error HasTotalBaseTokensError();
    error SingleVestingCliffError();
    error SingleVestingPeriodError();
    error HasTotalSingleTokensError();
    error LpNotZeroError();
    error NothingClaimedError();
    error SingleNothingClaimedError();
    error SingleDepositNotCompleted();
    error DepositNotFinalizedError();
    error MaxVestingPeriodsError();

    function singleHolderNotNull(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleHolderNotNullError();
        }
    }

    function notCancelled(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert NotCancelledError();
        }
    }

    function inDepositWindow(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert InDepositWindowError();
        }
    }

    function contractUnlocked(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert ContractUnlockedError();
        }
    }

    function notInitialized(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert NotInitializedError();
        }
    }

    function callerIsHolder(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert CallerIsHolderError();
        }
    }

    function depositIncomplete(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DepositIncompleteError();
        }
    }

    function depositWindowEnded(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DepositWindowEndedError();
        }
    }

    function inFundingWindow(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert InFundingWindowError();
        }
    }

    function vestingCliff(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert VestingCliffError();
        }
    }

    function vestingPeriod(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert VestingPeriodError();
        }
    }

    function singleVestingCliff(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleVestingCliffError();
        }
    }

    function singleVestingPeriod(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleVestingPeriodError();
        }
    }

    function investorShare(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert InvestorShareError();
        }
    }

    function hasTotalBaseTokens(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert HasTotalBaseTokensError();
        }
    }

    function hasTotalSingleTokens(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert HasTotalSingleTokensError();
        }
    }

    function lpNotZero(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert LpNotZeroError();
        }
    }

    function nothingClaimed(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert NothingClaimedError();
        }
    }

    function singleNothingClaimed(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleNothingClaimedError();
        }
    }

    function maxSingleReward(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert MaxSingleRewardError();
        }
    }

    function depositNotFinalized(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DepositNotFinalizedError();
        }
    }

    function maxVestingPeriods(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert MaxVestingPeriodsError();
        }
    }

    function poolExists(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert PoolExistsError();
        }
    }

    function allowListAndNftListNotAllowed(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert AllowListAndNFTListNotAllowedError();
        }
    }

    function allowListAndMerkleNotAllowed(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert AllowListAndMerkleNotAllowedError();
        }
    }

    function nftListAndMerkleNotAllowed(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert NFTListAndMerkleNotAllowedError();
        }
    }

    function merkleHasIPFSHash(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert MerkleHasIPFSHashError();
        }
    }

    function singleHolder(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleHolderError();
        }
    }

    function singleToken(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleTokenError();
        }
    }

    function singleTokenBalance(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleTokenBalance();
        }
    }

    function singleDepositNotFinalized(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleDepositNotFinalizedError();
        }
    }

    function lpVestingAndSingleArrayLength(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert LpVestingAndSingleArrayLengthError();
        }
    }

    function baseDepositNotCompleted(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert BaseDepositNotCompletedError();
        }
    }

    function vestingScheduleExists(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert VestingScheduleExistsError();
        }
    }

    function investmentTokenBalance(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert InvestmentTokenBalanceError();
        }
    }

    function investorAllocation(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert InvestorAllocationError();
        }
    }

    function liquidityLaunch(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert LiquidityLaunchError();
        }
    }

    function dealOpen(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DealOpenError();
        }
    }

    function purchaseAmount(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert PurchaseAmountError();
        }
    }

    function fundingComplete(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert FundingCompleteError();
        }
    }

    function baseTokenBalance(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert BaseTokenBalanceError();
        }
    }
}
