// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../Owned.sol";

contract AelinLibraryList is Owned {
    mapping(address => bool) public libraryList;

    constructor(address _aelinCouncil) Owned(_aelinCouncil) {}

    function addLibrary(address _newLibrary) external onlyOwner {
        libraryList[_newLibrary] = true;
    }
}
