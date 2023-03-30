// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./VestERC721.sol";
import "./interfaces/IVestVestingToken.sol";

contract VestVestingToken is VestERC721, IVestVestingToken {
    mapping(uint256 => VestVestingToken) public vestVestingToken;
    uint256 public tokenCount;

    function _burnVestingToken(uint256 _tokenId) internal {
        _burn(_tokenId);
        delete vestVestingToken[_tokenId];
    }

    function _mintVestingToken(
        address _to,
        uint256 _amount,
        uint256 _lpTimestamp,
        uint256[] _singleRewardTimestamps,
        uint8 _vestingScheduleIndex
    ) internal {
        _mint(_to, tokenCount);
        vestVestingToken[tokenCount] = VestVestingToken(
            _amount,
            _lpTimestamp,
            _singleRewardTimestamps,
            _vestingScheduleIndex
        );
        emit VestingTokenMinted(_to, tokenCount, _amount, _lpTimestamp, _singleRewardTimestamps, _vestingScheduleIndex);
        tokenCount += 1;
    }

    function transferVestingShare(
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public nonReentrant {
        VestVestingToken memory schedule = vestVestingToken[_tokenId];
        require(schedule.amountDeposited > 0, "schedule does not exist");
        require(_shareAmount > 0, "share amount should be > 0");
        require(schedule.amountDeposited > _shareAmount, "cant transfer more than share");
        vestVestingToken[_tokenId] = VestVestingToken(
            schedule.amountDeposited - _shareAmount,
            schedule.lastClaimedAt,
            schedule.lastClaimedAtRewardList,
            schedule.vestingScheduleIndex
        );
        _mintVestingToken(
            _to,
            _shareAmount,
            schedule.lastClaimedAt,
            schedule.lastClaimedAtRewardList,
            schedule.vestingScheduleIndex
        );
    }

    // NOTE I am not sure we can just leave transfer like this. Circle back later when have time
    function transfer(
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        _safeTransfer(msg.sender, _to, _tokenId, _data);
    }
}
