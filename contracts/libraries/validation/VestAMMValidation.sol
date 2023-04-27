// SPDX-License-Identifier: Muint256 indexIT
pragma solidity 0.8.6;

library Validate {
    error ContractLocked();
    error AlreadyInitialized();
    error CallerNotHolder(address holder, address caller);
    error DepositCompleted();
    error VestAMMCancelled();
    error DepositWindowEnded(uint256 lpFundingExpiry);
    error VestAMMNotInFundingWindow(bool depositCompleted, bool beforeDepositExpiry, bool afterLpFundingExpiry);
    error VestAMMNotInDepositWindow(bool depositCompleted, bool afterDepositExpiry);
    error VestingCliffTooLong(uint256 allowed, uint256 actual, uint256 index);
    error VestingPeriodTooLong(uint256 allowed, uint256 actual, uint256 index);
    error InvalidInvestorShare(uint256 maxAllowed, uint256 minAllowed, uint256 actual, uint256 index);
    error SingleVestingCliffTooLong(uint256 allowed, uint256 actual, uint256 index);
    error SingleVestingPeriodTooLong(uint256 allowed, uint256 actual, uint256 index);
    error SingleHolderAddressNull();
    error SingleTokensNotAllocated(uint256 index);
    error SingleClaimedNotZero(uint256 index);
    error SingleDepositNotCompleted(uint256 index);
    error BaseTokensNotAllocated(uint256 index);
    error TooManySingleRewards(uint256 allowed, uint256 actual, uint256 index);
    error TooManyVestingPeriods(uint256 allowed, uint256 actual);
    error AMMPoolDoesNotExist(address poolAddress);
    error ClaimedNotZero(uint256 index);
    error TotalLPNotZero(uint256 totalLPTokens, uint256 index);
    error AllowListAndNFTListNotAllowed();
    error AllowListAndMerkleNotAllowed();
    error NFTListAndMerkleNotAllowed();
    error IPFSHashNotProvided();
    error InvalidSinlgeHolder(address mainHolder, address singleHolder, address caller, uint256 index);
    error InvalidDepositSingleToken(address expected, address actual, uint256 index);
    error InsufficientSingleTokenBalance(uint256 expected, uint256 actual, uint256 index);
    error SingleDepositCompleted(uint256 index);
    error LpVestingAndSingleLengthsDoNotMatch(uint256 lpVestingArrayLength, uint256 singleArrayLength);
    error BaseAlreadyDeposited();
    error InvalidMainHolder(address mainHolder, address caller);
    error VestingScheduleDoesNotExist(uint256 index);
    error InsufficientInvestmentTokenBalance(uint256 expected, uint256 actual);
    error MoreThanAllocation(uint256 expected, uint256 actual);
    error LiquidityLaunchNotAllowed();
    error OnlyLiquidityLaunchAllowed();
    error WithdrawNotAllowed(bool depositComplete, uint256 lpFundingExpiry);
    error OnlyOwnerCanClaim(address owner, address caller);
    error NothingToClaim();
    error DealCancelled();
    error PurchaseAmountExceedsMax(
        uint256 alreadyPurchased,
        uint256 purchaseAmount,
        uint256 maxPurchaseAmount,
        bool bucketsFull,
        bool proportionalDeallocation
    );

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

    function depositWindowEnded(uint256 _lpDepositTime, uint256 _lpFundingExpiry) external view {
        if (_lpDepositTime == 0 && block.timestamp > _lpFundingExpiry) {
            revert DepositWindowEnded({lpFundingExpiry: _lpFundingExpiry});
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

    function vestingCliff(
        uint256 _allowed,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _allowed) {
            revert VestingCliffTooLong({allowed: _allowed, actual: _actual, index: _index});
        }
    }

    function vestingPeriod(
        uint256 _allowed,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _allowed) {
            revert VestingPeriodTooLong({allowed: _allowed, actual: _actual, index: _index});
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
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _maxAllowed || _actual <= _minAllowed) {
            revert InvalidInvestorShare({maxAllowed: _maxAllowed, minAllowed: _minAllowed, actual: _actual, index: _index});
        }
    }

    function hasTotalBaseTokens(uint256 _totalBaseTokens, uint256 _index) external pure {
        if (_totalBaseTokens == 0) {
            revert BaseTokensNotAllocated({index: _index});
        }
    }

    function hasTotalSingleTokens(uint256 _totalBaseTokens, uint256 _index) external pure {
        if (_totalBaseTokens == 0) {
            revert SingleTokensNotAllocated({index: _index});
        }
    }

    function lpNotZero(uint256 _totalLPTokens, uint256 _index) external pure {
        if (_totalLPTokens > 0) {
            revert TotalLPNotZero({totalLPTokens: _totalLPTokens, index: _index});
        }
    }

    function nothingClaimed(uint256 _claimed, uint256 _index) external pure {
        if (_claimed > 0) {
            revert ClaimedNotZero({index: _index});
        }
    }

    function singleNothingClaimed(uint256 _claimed, uint256 _index) external pure {
        if (_claimed > 0) {
            revert SingleClaimedNotZero({index: _index});
        }
    }

    function maxSingleReward(
        uint256 _allowed,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual > _allowed) {
            revert TooManySingleRewards({allowed: _allowed, actual: _actual, index: _index});
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

    function singleHolder(
        address _mainHolder,
        address _singleHolder,
        uint256 _index
    ) external view {
        if (_mainHolder != msg.sender && _singleHolder != msg.sender) {
            revert InvalidSinlgeHolder({
                mainHolder: _mainHolder,
                singleHolder: _singleHolder,
                caller: msg.sender,
                index: _index
            });
        }
    }

    function singleToken(
        address _expected,
        address _actual,
        uint256 _index
    ) external pure {
        if (_expected != _actual) {
            revert InvalidDepositSingleToken({expected: _expected, actual: _actual, index: _index});
        }
    }

    function singleTokenBalance(
        uint256 _expected,
        uint256 _actual,
        uint256 _index
    ) external pure {
        if (_actual < _expected) {
            revert InsufficientSingleTokenBalance({expected: _expected, actual: _actual, index: _index});
        }
    }

    function singleDepositNotFinalized(bool _depositFinalized, uint256 _index) external pure {
        if (_depositFinalized) {
            revert SingleDepositCompleted({index: _index});
        }
    }

    function lpVestingAndSingleArrayLength(uint256 _lpVestingArrayLength, uint256 _singleArrayLength) external pure {
        if (_lpVestingArrayLength != _singleArrayLength) {
            revert LpVestingAndSingleLengthsDoNotMatch({
                lpVestingArrayLength: _lpVestingArrayLength,
                singleArrayLength: _singleArrayLength
            });
        }
    }

    function baseDepositNotCompleted(bool _baseDeposited) external pure {
        if (_baseDeposited) {
            revert BaseAlreadyDeposited();
        }
    }

    function mainHolder(address _mainHolder) external view {
        if (_mainHolder != msg.sender) {
            revert InvalidMainHolder({mainHolder: _mainHolder, caller: msg.sender});
        }
    }

    function validateVestingScheduleExists(bool _exists, uint256 _index) external pure {
        if (!_exists) {
            revert VestingScheduleDoesNotExist({index: _index});
        }
    }

    function validateInvestmentTokenBalance(uint256 _expected, uint256 _actual) external pure {
        if (_actual < _expected) {
            revert InsufficientInvestmentTokenBalance({expected: _expected, actual: _actual});
        }
    }

    function allocation(uint256 expected, uint256 actual) external pure {
        if (actual > expected) {
            revert MoreThanAllocation({expected: expected, actual: actual});
        }
    }

    function notLiquidityLaunch(bool _isLiquidityLaunch) external pure {
        if (_isLiquidityLaunch) {
            revert LiquidityLaunchNotAllowed();
        }
    }

    function isLiquidityLaunch(bool _isLiquidityLaunch) external pure {
        if (!_isLiquidityLaunch) {
            revert OnlyLiquidityLaunchAllowed();
        }
    }

    function withdrawAllowed(bool _depositComplete, uint256 _lpFundingExpiry) external view {
        if (!_depositComplete || block.timestamp <= _lpFundingExpiry) {
            revert WithdrawNotAllowed({depositComplete: _depositComplete, lpFundingExpiry: _lpFundingExpiry});
        }
    }

    function owner(address _owner) external view {
        if (_owner != msg.sender) {
            revert OnlyOwnerCanClaim({owner: _owner, caller: msg.sender});
        }
    }

    function hasClaimBalance(uint256 _balance) external pure {
        if (_balance == 0) {
            revert NothingToClaim();
        }
    }

    function dealIsOpen(bool _dealOpen) external pure {
        if (!_dealOpen) {
            revert DealCancelled();
        }
    }

    function purchaseAmount(
        uint256 _alreadyPurchased,
        uint256 _purchaseAmount,
        uint256 _maxPurchaseAmount,
        bool _bucketsFull,
        bool _proporionalDeallocation
    ) external pure {
        if (_alreadyPurchased + _purchaseAmount > _maxPurchaseAmount && !_bucketsFull && !_proporionalDeallocation) {
            revert PurchaseAmountExceedsMax({
                alreadyPurchased: _alreadyPurchased,
                purchaseAmount: _purchaseAmount,
                maxPurchaseAmount: _maxPurchaseAmount,
                bucketsFull: _bucketsFull,
                proportionalDeallocation: _proporionalDeallocation
            });
        }
    }
}
