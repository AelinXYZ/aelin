// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AelinERC721} from "./AelinERC721.sol";
import {IAelinVestingToken} from "./interfaces/IAelinVestingToken.sol";

contract AelinVestingToken is AelinERC721, IAelinVestingToken {
    mapping(uint256 => VestingDetails) public vestingDetails;
    uint256 public tokenCount;

    function _mintVestingToken(address _to, uint256 _amount, uint256 _timestamp, uint256 _vestingIndex) internal {
        _mint(_to, tokenCount);
        vestingDetails[tokenCount] = VestingDetails(_amount, _timestamp, _vestingIndex);
        emit VestingTokenMinted(_to, tokenCount, _amount, _timestamp, _vestingIndex);
        tokenCount += 1;
    }

    function _burnVestingToken(uint256 _tokenId) internal {
        _burn(_tokenId);
        delete vestingDetails[_tokenId];
        emit VestingTokenBurned(_tokenId);
    }

    /**
     * @notice This function allows anyone to transfer their vesting share to another address.
     * @param _to The recipient of the vesting token.
     * @param _tokenId The token Id from which the user wants to trasnfer.
     * @param _shareAmount The amount of vesting share the user wants to transfer.
     */
    function transferVestingShare(address _to, uint256 _tokenId, uint256 _shareAmount) public nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "must be owner to transfer");
        VestingDetails memory schedule = vestingDetails[_tokenId];
        require(_shareAmount > 0, "share amount should be > 0");
        require(_shareAmount < schedule.share, "amout gt than current share");
        vestingDetails[_tokenId] = VestingDetails(
            schedule.share - _shareAmount,
            schedule.lastClaimedAt,
            schedule.vestingIndex
        );
        _mintVestingToken(_to, _shareAmount, schedule.lastClaimedAt, schedule.vestingIndex);
        emit VestingShareTransferred(msg.sender, _to, _tokenId, _shareAmount);
    }

    function transfer(address _to, uint256 _tokenId, bytes memory _data) public {
        _safeTransfer(msg.sender, _to, _tokenId, _data);
    }
}
