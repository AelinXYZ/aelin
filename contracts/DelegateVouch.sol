// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// Inheritance
import "./Owned.sol";

contract DelegateVouch is Owned {
    constructor(address _aelinCouncil) Owned(_aelinCouncil) {}

    function addDelegateVouch(address _delegate) external onlyOwner {
        emit AddDelegateVouch(_delegate);
    }

    function removeDelegateVouch(address _delegate) external onlyOwner {
        emit RemoveDelegateVouch(_delegate);
    }

    event AddDelegateVouch(address indexed delegate);
    event RemoveDelegateVouch(address indexed delegate);
}