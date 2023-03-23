// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinVestingToken} from "contracts/AelinVestingToken.sol";

contract DerivedAelinVestingToken is AelinVestingToken {
    function mintVestingToken(
        address _to,
        uint256 _amount,
        uint256 _timestamp
    ) public {
        _mintVestingToken(_to, _amount, _timestamp);
    }
}

contract AelinVestingTokenTest is Test, AelinTestUtils {
    DerivedAelinVestingToken public vestingToken;

    uint256 public constant MAX_UINT_SAFE = 10_000_000_000_000_000_000_000_000;

    event VestingTokenMinted(address indexed user, uint256 indexed tokenId, uint256 amount, uint256 lastClaimedAt);

    function setUp() public {
        vestingToken = new DerivedAelinVestingToken();
    }

    function mintToknes(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _timestamp1,
        uint256 _timestamp2,
        uint256 _timestamp3
    ) public {
        _amount1 = bound(_amount1, 1, MAX_UINT_SAFE);
        _amount2 = bound(_amount2, 1, MAX_UINT_SAFE);
        _amount3 = bound(_amount3, 1, MAX_UINT_SAFE);
        _timestamp1 = bound(_timestamp1, 1, MAX_UINT_SAFE);
        _timestamp2 = bound(_timestamp2, 1, MAX_UINT_SAFE);
        _timestamp3 = bound(_timestamp3, 1, MAX_UINT_SAFE);

        vestingToken.mintVestingToken(user1, _amount1, _timestamp1);
        vestingToken.mintVestingToken(user2, _amount2, _timestamp2);
        vestingToken.mintVestingToken(user3, _amount3, _timestamp3);
    }

    function testFuzz_TransferVestingShare_RevertWhen_NotOwner(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _timestamp1,
        uint256 _timestamp2,
        uint256 _timestamp3,
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public {
        mintToknes(_amount1, _amount2, _amount3, _timestamp1, _timestamp2, _timestamp3);
        vm.assume(_tokenId == 0 || _tokenId == 1 || _tokenId == 2);
        vm.assume(user1 != vestingToken.ownerOf(_tokenId));

        vm.startPrank(user1);
        vm.expectRevert("must be owner to transfer");
        vestingToken.transferVestingShare(_to, _tokenId, _shareAmount);
        vm.stopPrank();
    }

    function test_TransferVestingShare_RevertWhen_ShareAmountIsZero(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _timestamp1,
        uint256 _timestamp2,
        uint256 _timestamp3,
        address _to,
        uint256 _tokenId
    ) public {
        mintToknes(_amount1, _amount2, _amount3, _timestamp1, _timestamp2, _timestamp3);
        vm.assume(_tokenId == 0 || _tokenId == 1 || _tokenId == 2);

        vm.startPrank(vestingToken.ownerOf(_tokenId));
        vm.expectRevert("share amount should be > 0");
        vestingToken.transferVestingShare(_to, _tokenId, 0);
        vm.stopPrank();
    }

    function test_TransferVestingShare_RevertWhen_ShareAmountIsMoreThanCurrentShare(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _timestamp1,
        uint256 _timestamp2,
        uint256 _timestamp3,
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public {
        mintToknes(_amount1, _amount2, _amount3, _timestamp1, _timestamp2, _timestamp3);
        vm.assume(_tokenId == 0 || _tokenId == 1 || _tokenId == 2);

        (uint256 share, ) = vestingToken.vestingDetails(_tokenId);

        vm.assume(_shareAmount > share);

        vm.startPrank(vestingToken.ownerOf(_tokenId));
        vm.expectRevert("cant transfer more than current share");
        vestingToken.transferVestingShare(_to, _tokenId, _shareAmount);
        vm.stopPrank();
    }

    function test_TransferVestingShare(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _timestamp1,
        uint256 _timestamp2,
        uint256 _timestamp3,
        address _to,
        uint256 _tokenId,
        uint256 _shareAmount
    ) public {
        mintToknes(_amount1, _amount2, _amount3, _timestamp1, _timestamp2, _timestamp3);
        vm.assume(_tokenId == 0 || _tokenId == 1 || _tokenId == 2);
        vm.assume(_to != address(0));

        uint256 prevTokenCount = vestingToken.tokenCount();
        (uint256 share, uint256 lastClaimedAt) = vestingToken.vestingDetails(_tokenId);

        vm.assume(_shareAmount > 0 && _shareAmount < share);

        vm.startPrank(vestingToken.ownerOf(_tokenId));
        vm.expectEmit(true, true, true, true, address(vestingToken));
        emit VestingTokenMinted(_to, prevTokenCount, _shareAmount, lastClaimedAt);
        vestingToken.transferVestingShare(_to, _tokenId, _shareAmount);
        vm.stopPrank();

        (uint newShare, uint256 newLastClaimedAt) = vestingToken.vestingDetails(prevTokenCount);

        assertEq(vestingToken.ownerOf(prevTokenCount), _to, "ownership transfered correctly");
        assertEq(vestingToken.tokenCount(), prevTokenCount + 1, "new vesting token minted");
        assertEq(newShare, _shareAmount, "share amount is correct");
        assertEq(lastClaimedAt, newLastClaimedAt, "last claimed at is correct");
    }
}
