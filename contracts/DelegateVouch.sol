// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// Inheritance
import "./Owned.sol";

contract DelegateVouch is Owned {
    constructor(address _aelinCouncil) Owned(_aelinCouncil) {}

    function delegateVouch(address _delegate) external onlyOwner {
        emit DelegateVouch(_delegate);
    }

    event DelegateVouch(address indexed delegate);
}
