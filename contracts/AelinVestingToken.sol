// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC721.sol";
import "./interfaces/IAelinVestingToken.sol";

contract AelinVestingToken is AelinERC721, IAelinVestingToken {
    mapping(uint256 => TokenDetails) public tokenDetails;
    uint256 public tokenCount;

    function _mintVestingToken(
        address _to,
        uint256 _amount,
        uint256 _timestamp
    ) internal {
        _mint(_to, tokenCount);
        tokenDetails[tokenCount] = TokenDetails(_amount, _timestamp);
        emit VestingTokenMinted(_to, tokenCount, _amount, _timestamp);
        tokenCount += 1;
    }

    function transferVestingShare(
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public nonReentrant {
        TokenDetails memory schedule = tokenDetails[_tokenId];
        require(schedule.share > 0, "schedule does not exist");
        require(_shareAmount > 0, "share amount should be > 0");
        require(schedule.share > _shareAmount, "cant transfer more than current share");
        tokenDetails[_tokenId] = TokenDetails(schedule.share - _shareAmount, schedule.lastClaimedAt);
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
