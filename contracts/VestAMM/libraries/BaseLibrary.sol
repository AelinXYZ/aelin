// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library BaseLibrary {
    struct DepositData {
        uint256 lpDepositTime;
        address lpToken;
        uint256 lpTokenAmount;
        mapping(uint8 => uint256) lpTokenAmountPerSchedule;
    }
    struct DeployPool {
        uint256 investmentTokenAmount;
        uint256 baseTokenAmount;
    }
}
