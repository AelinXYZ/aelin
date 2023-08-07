// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VestAMMRegistry is Ownable {
    mapping(address => bool) public vestAMMExists;

    constructor(address _aelinCouncil) {
        _transferOwnership(_aelinCouncil);
    }

    function addVestAMM(address _newVestAMM) external onlyOwner {
        vestAMMExists[_newVestAMM] = true;

        /// @dev add events?
    }

    function removeVestAMM(address _removedVestAMM) external onlyOwner {
        vestAMMExists[_removedVestAMM] = false;
    }
}
