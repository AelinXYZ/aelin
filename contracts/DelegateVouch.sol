// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// Inheritance
import "./Owned.sol";

contract DelegateVouch is Owned {
    mapping (address => bool) public isDelegate;

    constructor(address _aelinCouncil) Owned(_aelinCouncil) {}

    function addDelegateVouch(address _delegate) external onlyOwner {
        isDelegate[_delegate] = true;
        emit AddDelegateVouch(_delegate);
    }

    function removeDelegateVouch(address _delegate) external onlyOwner {
        isDelegate[_delegate] = false;
        emit RemoveDelegateVouch(_delegate);
    }

    event AddDelegateVouch(address indexed delegate);
    event RemoveDelegateVouch(address indexed delegate);
}