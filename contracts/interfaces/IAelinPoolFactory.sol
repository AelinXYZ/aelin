// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IAelinPoolFactory {
    struct PoolData {
        string name;
        string symbol;
        uint256 purchaseTokenCap;
        address purchaseToken;
        uint256 duration;
        uint256 sponsorFee;
        uint256 purchaseDuration;
    }

    function createPool(
        PoolData memory _poolData,
        address[] memory _allowList,
        uint256[] memory _allowListAmounts
    ) external returns (address);
}
