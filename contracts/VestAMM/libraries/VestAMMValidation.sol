// SPDX-License-Identifier: Muint256 indexIT
pragma solidity 0.8.6;

library Validate {
    error BaseTokenBalanceError();
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
    error PoolExistsError();
    error AllowListAndNFTListNotAllowedError();
    error AllowListAndMerkleNotAllowedError();
    error NFTListAndMerkleNotAllowedError();
    error MerkleHasIPFSHashError();
    error SingleHolderError();
    error SingleTokenError();
    error SingleDepositNotFinalizedError();
    error LpVestingAndSingleArrayLengthError();
    error MaxSingleRewardError();
    error BaseDepositNotCompletedError();
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
    error SingleDepositNotCompleted();
    error DepositNotFinalizedError();
    error MaxVestingPeriodsError();
    error MaxExcessBaseTokensError();
    error DealHasLiquidityLaunch();
    error IsNotOwner();
    error DoesNotHaveClaimableBalance();

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

    function singleDepositNotFinalized(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert SingleDepositNotFinalizedError();
        }
    }

    function baseDepositNotCompleted(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert BaseDepositNotCompletedError();
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

    function maxExcessBaseTokens(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert MaxExcessBaseTokensError();
        }
    }

    function notLiquidityLaunch(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DealHasLiquidityLaunch();
        }
    }

    function isOwner(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert IsNotOwner();
        }
    }

    function hasClaimBalance(bool _conditionMet) external pure {
        if (!_conditionMet) {
            revert DoesNotHaveClaimableBalance();
        }
    }
}
