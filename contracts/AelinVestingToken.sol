// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC721.sol";
import "./interfaces/IAelinVestingToken.sol";

contract AelinVestingToken is AelinERC721, IAelinVestingToken {
    mapping(uint256 => VestingDetails) public vestingDetails;
    uint256 public tokenCount;

    function _mintVestingToken(
        address _to,
        uint256 _amount,
        uint256 _timestamp
    ) internal {
        _mint(_to, tokenCount);
        vestingDetails[tokenCount] = VestingDetails(_amount, _timestamp);
        emit VestingTokenMinted(_to, tokenCount, _amount, _timestamp);
        tokenCount += 1;
    }

    function _burnVestingToken(uint256 _tokenId) internal {
        _burn(_tokenId);
        delete vestingDetails[_tokenId];
        emit VestingTokenBurned(_tokenId);
    }

    function transferManyVestTokens(
        address _to,
        uint256[] calldata _fullTransferTokenIds,
        uint256 _partialTransferID,
        uint256 _partialShareAmount
    ) public nonReentrant {
        for (uint256 i = 0; i < _fullTransferTokenIds.length; i++) {
            transfer(_to, _fullTransferTokenIds[i], bytes(""));
        }
        transferVestingShare(_to, _partialTransferID, _partialShareAmount);
    }

    function transferVestingShare(
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "must be owner to transfer");
        VestingDetails memory schedule = vestingDetails[_tokenId];
        require(_shareAmount > 0, "share amount should be > 0");
        require(_shareAmount < schedule.share, "cant transfer more than current share");
        vestingDetails[_tokenId] = VestingDetails(schedule.share - _shareAmount, schedule.lastClaimedAt);
        _mintVestingToken(_to, _shareAmount, schedule.lastClaimedAt);
        emit VestingShareTransferred(msg.sender, _to, _tokenId, _shareAmount);
    }

    function transfer(
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        _safeTransfer(msg.sender, _to, _tokenId, _data);
    }
}
