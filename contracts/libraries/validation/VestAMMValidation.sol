// SPDX-License-Identifier: Muint256 indexIT
pragma solidity 0.8.6;

library Validate {
    error ContractLocked();
    error AlreadyInitialized();
    error CallerNotHolder(address holder, address caller);
    error DepositCompleted();
    error VestAMMCancelled();
    error VestAMMNotCancelled(bool isCancelled, uint256 lpDepositTime, uint256 lpFundingExpiry);
    error VestAMMNotInFundingWindow(bool depositCompleted, bool beforeDepositExpiry, bool afterLpFundingExpiry);
    error VestAMMNotInDepositWindow(bool depositCompleted, bool afterDepositExpiry);
    error VestingCliffTooLong(uint256 allowed, uint256 actual);
    error VestingPeriodTooLong(uint256 allowed, uint256 actual);
    error InvalidInvestorShare(uint256 maxAllowed, uint256 minAllowed, uint256 actual);
    error SingleVestingCliffTooLong(uint256 allowed, uint256 actual, uint256 index);
    error SingleVestingPeriodTooLong(uint256 allowed, uint256 actual, uint256 index);
    error SingleHolderAddressNull();
    error SingleTokensNotAllocated(uint256 index);
    error SingleClaimedNotZero(uint256 index);
    error SingleDepositNotCompleted(uint256 index);
    error BaseTokensNotAllocated();
    error TooManySingleRewards(uint256 allowed, uint256 actual);
    error TooManyVestingPeriods(uint256 allowed, uint256 actual);
    error AMMPoolDoesNotExist(address poolAddress);
    error ClaimedNotZero();
    error AllowListAndNFTListNotAllowed();
    error AllowListAndMerkleNotAllowed();
    error NFTListAndMerkleNotAllowed();
    error IPFSHashNotProvided();
    error InvalidHolderDepositSinlge(address mainHolder, address singleHolder, address caller);
    error InvalidDepositSingleToken(address expected, address actual, uint256 index);

    function singleHolderNotNull(address _address) external pure {
        if (_address == address(0)) {
            revert SingleHolderAddressNull();
        }
    }

    function inDepositWindow(
        bool _isCancelled,
        bool _depositComplete,
        uint256 _depositExpiry
    ) external view {
        if (_isCancelled) {
            revert VestAMMCancelled();
        }

        if (!_depositComplete || block.timestamp > _depositExpiry) {
            revert VestAMMNotInDepositWindow({
                depositCompleted: _depositComplete,
                afterDepositExpiry: block.timestamp > _depositExpiry
            });
        }
    }

    function isUnlocked(bool _locked) external pure {
        if (_locked) {
            revert ContractLocked();
        }
    }

    function isNotInitialize(bool _initialized) external pure {
        if (_initialized) {
            revert AlreadyInitialized();
        }
    }

    function callerIsHolder(address _holder) external view {
        if (msg.sender != _holder) {
            revert CallerNotHolder({holder: _holder, caller: msg.sender});
        }
    }

    function depositIncomplete(bool _completed) external pure {
        if (_completed) {
            revert DepositCompleted();
        }
    }

    function isCancelled(
        bool _isCancelled,
        uint256 _lpDepositTime,
        uint256 _lpFundingExpiry
    ) external view {
        if (!_isCancelled && (_lpDepositTime > 0 || block.timestamp <= _lpFundingExpiry)) {
            revert VestAMMNotCancelled({
                isCancelled: _isCancelled,
                lpDepositTime: _lpDepositTime,
                lpFundingExpiry: _lpFundingExpiry
            });
        }
    }

    function inFundingWindow(
        bool _isCancelled,
        bool _depositComplete,
        uint256 _depositExpiry,
        uint256 _lpFundingExpiry
    ) external view {
        if (_isCancelled) {
            revert VestAMMCancelled();
        }

        if (!_depositComplete || block.timestamp <= _depositExpiry || block.timestamp > _lpFundingExpiry) {
            revert VestAMMNotInFundingWindow({
                depositCompleted: _depositComplete,
                beforeDepositExpiry: block.timestamp <= _depositExpiry,
                afterLpFundingExpiry: block.timestamp > _lpFundingExpiry
            });
        }
    }

    function vestingCliff(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) {
            revert VestingCliffTooLong({allowed: _allowed, actual: _actual});
        }
    }

    function vestingPeriod(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) {
            revert VestingPeriodTooLong({allowed: _allowed, actual: _actual});
        }
    }

    function singleVestingCliff(
        uint256 _allowed,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _allowed) {
            revert SingleVestingCliffTooLong({allowed: _allowed, actual: _actual, index: _index});
        }
    }

    function singleVestingPeriod(
        uint256 _allowed,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _allowed) {
            revert SingleVestingPeriodTooLong({allowed: _allowed, actual: _actual, index: _index});
        }
    }

    function investorShare(
        uint256 _maxAllowed,
        uint256 _minAllowed,
        uint256 _actual
    ) external pure {
        if (_actual > _maxAllowed || _actual <= _minAllowed) {
            revert InvalidInvestorShare({maxAllowed: _maxAllowed, minAllowed: _minAllowed, actual: _actual});
        }
    }

    function hasTotalBaseTokens(uint256 _totalBaseTokens) external pure {
        if (_totalBaseTokens == 0) {
            revert BaseTokensNotAllocated();
        }
    }

    function hasTotalSingleTokens(uint256 _totalBaseTokens, uint256 _index) external pure {
        if (_totalBaseTokens == 0) {
            revert SingleTokensNotAllocated({index: _index});
        }
    }

    function nothingClaimed(uint256 _claimed) external pure {
        if (_claimed > 0) {
            revert ClaimedNotZero();
        }
    }

    function singleNothingClaimed(uint256 _claimed, uint256 _index) external pure {
        if (_claimed > 0) {
            revert SingleClaimedNotZero({index: _index});
        }
    }

    function maxSingleReward(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) {
            revert TooManySingleRewards({allowed: _allowed, actual: _actual});
        }
    }

    function depositNotFinalized(bool _depositFinalized, uint256 _index) external pure {
        if (!_depositFinalized) {
            revert SingleDepositNotCompleted({index: _index});
        }
    }

    function maxVestingPeriods(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) {
            revert TooManyVestingPeriods({allowed: _allowed, actual: _actual});
        }
    }

    function poolExists(bool _poolExists, address _poolAddress) external pure {
        if (!_poolExists) {
            revert AMMPoolDoesNotExist({poolAddress: _poolAddress});
        }
    }

    function allowListAndNftListNotAllowed(bool _hasBoth) external pure {
        if (_hasBoth) {
            revert AllowListAndNFTListNotAllowed();
        }
    }

    function allowListAndMerkleNotAllowed(bool _hasBoth) external pure {
        if (_hasBoth) {
            revert AllowListAndMerkleNotAllowed();
        }
    }

    function nftListAndMerkleNotAllowed(bool _hasBoth) external pure {
        if (_hasBoth) {
            revert NFTListAndMerkleNotAllowed();
        }
    }

    function hasIPFSHash(bool _hashExists) external pure {
        if (!_hashExists) {
            revert IPFSHashNotProvided();
        }
    }

    function holderDepositSingle(address _mainHolder, address _singleHolder) external view {
        if (_mainHolder != msg.sender && _singleHolder != msg.sender) {
            revert InvalidHolderDepositSinlge({mainHolder: _mainHolder, singleHolder: _singleHolder, caller: msg.sender});
        }
    }

    function depositSingleToken(
        address _expected,
        address _actual,
        uint256 _index
    ) external pure {
        if (_expected != _actual) {
            revert InvalidDepositSingleToken({expected: _expected, actual: _actual, index: _index});
        }
    }
}
