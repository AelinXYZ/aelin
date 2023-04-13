// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library Validate {
    error AlreadyInitialized();
    error CallerIsNotHolder(address holder, address caller);
    error DepositIsCompleted();
    error VaMMCancelled();
    error VaMMNotInFundingWindow(bool depositCompleted, bool afterDepositExpiry, bool beforeLpFundingExpiry);
    error VestingCliffTooLong(uint256 allowed, uint256 actual);
    error VestingPeriodTooLong(uint256 allowed, uint256 actual);
    error InvalidInvestorShare(uint256 allowed, uint256 actual);

    function isNotInitialize(bool _initialized) external pure {
        if (_initialized) revert AlreadyInitialized();
    }

    function callerIsHolder(address _holder) external view {
        if (msg.sender != _holder) revert CallerIsNotHolder({holder: _holder, caller: msg.sender});
    }

    function depositIncomplete(bool _completed) external pure {
        if (_completed) revert DepositIsCompleted();
    }

    function vammIsCancelled(
        bool _isCancelled,
        uint256 _lpDepositTime,
        uint256 _lpFundingExpiry
    ) external view {
        if (!_isCancelled && (_lpDepositTime > 0 || block.timestamp <= _lpFundingExpiry)) revert VaMMCancelled();
    }

    function vammInFundingWindow(
        bool _isCancelled,
        bool _depositComplete,
        uint256 _depositExpiry,
        uint256 _lpFundingExpiry
    ) external view {
        if (_isCancelled) revert VaMMCancelled();

        if (_depositComplete && block.timestamp > _depositExpiry && block.timestamp <= _lpFundingExpiry)
            revert VaMMNotInFundingWindow({
                depositCompleted: _depositComplete,
                afterDepositExpiry: block.timestamp > _depositExpiry,
                beforeLpFundingExpiry: block.timestamp <= _lpFundingExpiry
            });
    }

    function vestingCliff(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) revert VestingCliffTooLong({allowed: _allowed, actual: _actual});
    }

    function vestingPeriod(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) revert VestingPeriodTooLong({allowed: _allowed, actual: _actual});
    }

    function investorShare(uint256 _allowed, uint256 _actual) external pure {
        if (_actual > _allowed) revert InvalidInvestorShare({allowed: _allowed, actual: _actual});
    }
}
