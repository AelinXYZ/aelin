// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library Validate {
    error AlreadyInitialized();
    error CallerIsNotHolder(address holder, address caller);
    error DepositIsCompleted();
    error VaMMIsNotCancelled();
    error VaMMNotInFundingWindow(bool depositCompleted, bool afterDepositExpiry, bool beforeLpFundingExpiry);
    error VestingCliffTooLong(uint256 allowed, uint256 actual);

    function isNotInitialize(bool _initialized) external pure {
        if (_initialized) revert AlreadyInitialized();
    }

    function callerIsHolder(address _holder) external view {
        if (msg.sender != _holder) revert CallerIsNotHolder({holder: _holder, caller: msg.sender});
    }

    function depositIsNotCompleted(bool _completed) external pure {
        if (_completed) revert DepositIsCompleted();
    }

    function vammIsCancelled(bool _cancelled) external pure {
        if (!_cancelled) revert VaMMIsNotCancelled();
    }

    function vammIsInFundingWindow(
        bool _depositComplete,
        uint256 _depositExpiry,
        uint256 _lpFundingExpiry
    ) external view {
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
}
