// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IVestVestingToken {
    struct VestVestingToken {
        uint256 amountDeposited;
        uint256 lastClaimedAt;
        uint256[] lastClaimedAtRewardList;
        uint8 vestingScheduleIndex;
    }

    event VestingTokenMinted(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 lastClaimedAt,
        uint256[] lastClaimedAtRewardList,
        uint8 vestingScheduleIndex
    );
}
