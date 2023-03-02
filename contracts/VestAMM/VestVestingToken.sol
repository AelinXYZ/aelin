// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./VestERC721.sol";
import "./interfaces/IVestVestingToken.sol";

contract VestVestingToken is VestERC721, IVestVestingToken {
    mapping(uint256 => VestVestingToken) public vestVestingToken;
    mapping(address => uint256) public addressToNFT;
    uint256 public tokenCount;

    function _burnVestingToken(uint256 _tokenId) internal {
        _burn(_tokenId);
        delete vestVestingToken[_tokenId];
    }

    function _mintVestingToken(
        address _to,
        uint256 _amount,
        uint256 _timestamp
    ) internal {
        // TODO confirm how to check if exists. this is probably wrong.
        if (addressToNFT[_to]) {
            VestVestingToken memory schedule = vestVestingToken[addressToNFT[_to]];
            vestVestingToken[addressToNFT[_to]] = VestVestingToken(
                schedule.amountDeposited + _amount,
                schedule.lastClaimedAt,
                schedule.lastClaimedAtRewardList
            );
            emit VestingTokenAdded(_to, addressToNFT[_to], _amount, _timestamp);
        } else {
            _mint(_to, tokenCount);
            vestVestingToken[tokenCount] = VestVestingToken(_amount, _timestamp);
            emit VestingTokenMinted(_to, tokenCount, _amount, _timestamp);
            tokenCount += 1;
        }
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
        // NOTE can we just update the one field we are changing like vestVestingToken[_tokenId].amountDeposited = ...
        vestVestingToken[_tokenId] = VestVestingToken(
            schedule.amountDeposited - _shareAmount,
            schedule.lastClaimedAt,
            schedule.lastClaimedAtRewardList
        );
        _mintVestingToken(_to, _shareAmount, schedule.lastClaimedAt);
    }

    function transfer(
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        _safeTransfer(msg.sender, _to, _tokenId, _data);
    }
}
