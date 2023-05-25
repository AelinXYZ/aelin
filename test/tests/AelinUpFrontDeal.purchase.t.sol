// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinNftGating} from "contracts/libraries/AelinNftGating.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MerkleTree} from "contracts/libraries/MerkleTree.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AelinUpFrontDealPurchaseTest is Test, AelinTestUtils, IAelinUpFrontDeal {
    AelinUpFrontDeal public testUpFrontDeal;
    AelinFeeEscrow public testEscrow;
    AelinUpFrontDealFactory public upFrontDealFactory;

    address dealAddressNoDeallocationNoDeposit;
    address dealAddressAllowDeallocationNoDeposit;
    address dealAddressNoDeallocation;
    address dealAddressAllowDeallocation;
    address dealAddressAllowList;
    address dealAddressNftGating721;
    address dealAddressNftGating1155;
    address dealAddressNftGating721IdRanges;
    address dealAddressMultipleVestingSchedules;

    function setUp() public {
        AelinAllowList.InitData memory allowListEmpty;
        AelinAllowList.InitData memory allowList = getAllowList();
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);

        vm.startPrank(dealCreatorAddress);

        // Deal initialization
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfigAllowDeallocation = getDealConfigAllowDeallocation();
        IAelinUpFrontDeal.UpFrontDealConfig
            memory dealConfigMultipleVestingSchedules = getDealConfigMultipleVestingSchedules();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721IdRanges = getERC721Collection();
        nftCollectionRules721IdRanges[0].idRanges = getERC721IdRanges();

        dealAddressNoDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressNoDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowList = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowList
        );

        dealAddressNftGating721 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721,
            allowListEmpty
        );

        dealAddressNftGating1155 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules1155,
            allowListEmpty
        );

        dealAddressNftGating721IdRanges = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721IdRanges,
            allowListEmpty
        );

        dealAddressMultipleVestingSchedules = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigMultipleVestingSchedules,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        vm.stopPrank();
        vm.startPrank(dealHolderAddress);

        // Deposit underlying tokens to save time for next tests
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowList), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowList).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating1155).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721IdRanges), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressMultipleVestingSchedules), type(uint256).max);
        AelinUpFrontDeal(dealAddressMultipleVestingSchedules).depositUnderlyingTokens(1e35);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
						depositUnderlyingTokens()
	//////////////////////////////////////////////////////////////*/

    function testFuzz_DepositUnderlyingTokens_RevertWhen_NotHolder(address _testAddress, uint256 _depositAmount) public {
        vm.assume(_testAddress != dealHolderAddress);
        vm.startPrank(_testAddress);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testFuzz_DepositUnderlyingTokens_RevertWhen_NoBalance(uint256 _depositAmount, uint256 _holderBalance) public {
        vm.assume(_holderBalance < _depositAmount);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, _holderBalance);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), _holderBalance);
        vm.expectRevert("not enough balance");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testFuzz_DepositUnderlyingTokens_RevertWhen_AlreadyDeposited(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressNoDeallocation).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testFuzz_DepositUnderlyingTokens_PartialDeposits(
        uint256 _firstDepositAmount,
        uint256 _secondDepositAmount
    ) public {
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);

        // first deposit
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        (bool success, uint256 result) = SafeMath.tryAdd(_firstDepositAmount, _secondDepositAmount);
        vm.assume(success);
        vm.assume(result >= underlyingDealTokenTotal);
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        vm.assume(_firstDepositAmount < underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _firstDepositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_firstDepositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _firstDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0), 0);

        // second deposit
        balanceBeforeDeposit = balanceAfterDeposit;
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _secondDepositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_secondDepositAmount);
        balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _secondDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0),
            block.timestamp + 10 days + 60 days + 365 days
        );

        vm.stopPrank();
    }

    function testFuzz_DepositUnderlyingTokens_FullDeposit(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);

        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);

        // deposit initiated
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _depositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _depositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0),
            block.timestamp + 10 days + 60 days + 365 days
        );

        // should revert when trying to deposit again
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);

        vm.stopPrank();
    }

    function testFuzz_DepositUnderlyingTokens_DepositByDirectTransfer(address _depositor, uint256 _depositAmount) public {
        vm.assume(_depositor != dealHolderAddress);
        vm.assume(_depositor != address(0));
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.startPrank(_depositor);

        // random wallet sends the funds
        deal(address(underlyingDealToken), _depositor, type(uint256).max);
        underlyingDealToken.transfer(dealAddressNoDeallocationNoDeposit, _depositAmount);
        assertEq(
            underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit)),
            _depositAmount + balanceBeforeDeposit
        );
        assertGe(underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit)), underlyingDealTokenTotal);

        // deposit is still not complete
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0), 0);

        // depositUnderlyingTokens() still needs to be called
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, 0);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(0);

        // deposit is now flagged as completed
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0),
            block.timestamp + 10 days + 60 days + 365 days
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        setHolder() / acceptHolder()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SetHolder_RevertWhen_CallerNotHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(_futureHolder);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(holderAddress, dealHolderAddress);
        vm.stopPrank();
    }

    function test_SetHolder_RevertWhen_HolderIsZero() public {
        vm.startPrank(dealHolderAddress);
        vm.expectRevert("holder cant be null");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(address(0));
        vm.stopPrank();
    }

    function testFuzz_SetHolder_RevertWhen_NotDesignatedHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.assume(_futureHolder != address(0));
        vm.startPrank(dealHolderAddress);

        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).futureHolder(), _futureHolder);
        vm.expectRevert("only future holder can access");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptHolder();
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(holderAddress, dealHolderAddress);

        vm.stopPrank();
    }

    function testFuzz_SetHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.assume(_futureHolder != address(0));
        vm.startPrank(dealHolderAddress);
        address temHolderAddress;

        vm.expectEmit(true, false, false, false);
        emit HolderSet(_futureHolder);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).futureHolder(), _futureHolder);
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(temHolderAddress, dealHolderAddress);
        vm.stopPrank();

        vm.startPrank(_futureHolder);
        vm.expectEmit(true, false, false, false);
        emit HolderAccepted(_futureHolder);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptHolder();
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(temHolderAddress, _futureHolder);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
						        vouch()
	//////////////////////////////////////////////////////////////*/

    function testFuzz_Vouch(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddressNoDeallocationNoDeposit));
        emit Vouch(_attestant);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vouch();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
							    disavow()
	//////////////////////////////////////////////////////////////*/

    function testFuzz_Disavow(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddressNoDeallocationNoDeposit));
        emit Disavow(_attestant);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).disavow();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
							withdrawExcess()
	//////////////////////////////////////////////////////////////*/

    function testFuzz_WithdrawExcess_RevertWhen_NotHolder(address _initiator) public {
        vm.assume(_initiator != dealHolderAddress);
        vm.startPrank(_initiator);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        vm.stopPrank();
    }

    function testFuzz_WithdrawExcess_RevertWhen_NoExcessToWithdraw(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        vm.assume(_depositAmount <= underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.expectRevert("no excess to withdraw");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        vm.stopPrank();
    }

    function testFuzz_WithdrawExcess(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        vm.assume(_depositAmount > underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterTransfer = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        uint256 expectedWithdraw = balanceAfterTransfer - underlyingDealTokenTotal;
        vm.expectEmit(false, false, false, false);
        emit WithdrewExcess(address(dealAddressNoDeallocationNoDeposit), expectedWithdraw);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        assertEq(underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit), underlyingDealTokenTotal);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                acceptDeal()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_AcceptDeal_RevertWhen_DepositIncomplete(address _user, uint256 _purchaseAmount) public {
        vm.startPrank(_user);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            _purchaseAmount,
            0
        );
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_NotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        // deposit to start purchase period
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(underlyingDealTokenTotal);
        vm.stopPrank();

        // warp past purchase period and try to accept deal
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.startPrank(_user);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            _purchaseAmount,
            0
        );

        // try on a contract that was deposited during intialize
        purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            _purchaseAmount,
            0
        );
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_BalanceTooLow() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint256 tokenAmount = 100;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, tokenAmount);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectRevert("not enough purchaseToken");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, tokenAmount + 1, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_AmountOverAllocation() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        (, , uint256 allocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user1);
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, allocatedAmount + 1, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_AmountTooSmall() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("purchase amount too small");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, 0, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_AmountOverTotal() public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);

        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;

        // User 1 tries to deposit more than the total purchase amount
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        uint256 expectedPoolShareAmount = ((raiseAmount + 1e18) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        assertGt(expectedPoolShareAmount, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, raiseAmount + 1e18, 0);

        // User 1 now deposits less than the total purchase amount
        uint256 purchaseAmount1 = raiseAmount - 2e18;
        expectedPoolShareAmount = (purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, purchaseAmount1, purchaseAmount1, expectedPoolShareAmount, expectedPoolShareAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1, 0);
        vm.stopPrank();

        // User 2 now deposits more than the total purchase amount
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        uint256 purchaseAmount2 = purchaseAmount1 + 3e18;
        uint256 totalPoolShares = ((purchaseAmount2 + purchaseAmount1) * 10 ** underlyingTokenDecimals) /
            purchaseTokenPerDealToken;
        assertGt(totalPoolShares, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_NotInAllowList(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user4);
        deal(address(purchaseToken), user4, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_PoolHasNoNftList(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("pool does not have an NFT list");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_EmptyNftList(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        vm.assume(_purchaseAmount > 1e18);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("collection should not be null");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_NoNftList(uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("must provide purchase list");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_CollectionNotSupported(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(420);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("collection not in the pool");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_NotERC721Owner(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collection721_1).mint(user2, 1);
        MockERC721(collection721_1).mint(user2, 2);
        vm.expectRevert("has to be the token owner");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_NoERC721TokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collection721_1).mint(user2, 1);
        MockERC721(collection721_1).mint(user2, 2);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_InvalidERC721TokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 4;
        tokenIdsArray[1] = 5;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collection721_1).mint(user2, 1);
        MockERC721(collection721_1).mint(user2, 2);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_ERC721TokenIdNotInRange(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721IdRanges), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 14;
        tokenIdsArray[1] = 15;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        //These token Ids aren't in the range specified by the collection rules
        MockERC721(collection721_1).mint(user1, 14);
        MockERC721(collection721_1).mint(user1, 15);
        vm.expectRevert("tokenId not in range");
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_ERC721OverAllowance(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);

        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount > raiseAmount);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);

        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC721(collection721_1).mint(user1, 1);
        MockERC721(collection721_1).mint(user1, 2);

        vm.startPrank(user1);
        vm.expectRevert("purchase amount greater than max");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    // User has no tokens at all
    function testFuzz_AcceptDeal_RevertWhen_Not1155Owner(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collection1155_1).mint(user2, 1, 1, "");
        MockERC1155(collection1155_1).mint(user2, 2, 1, "");
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    // If user has tokens but not enough (balance < minTokensEligible)
    function testFuzz_AcceptDeal_RevertWhen_NotEnough1155(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collection1155_1).mint(user1, 1, 1, "");
        MockERC1155(collection1155_1).mint(user1, 2, 1, "");
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_1155NotInList(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 10;
        tokenIdsArray[1] = 11;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collection1155_1).mint(user1, 10, 1, "");
        MockERC1155(collection1155_1).mint(user1, 11, 1, "");
        vm.expectRevert("tokenId not in the pool");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_Null1155Id(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collection1155_1).mint(user1, 10, 1, "");
        MockERC1155(collection1155_1).mint(user1, 11, 1, "");
        vm.expectRevert("tokenId not in the pool");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_PurchaseOverMerkleAllowance() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;

        merkleData.account = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        merkleData.index = 1;
        merkleData.amount = 300000000000000000000;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0xf8eca5b74c7de2055c42c0b1e97899698926417126af5f27ee7632e778ec82c6;
        merkleData.merkleProof[1] = 0xc4f80bb918ef5e099536eccc61682977f69bf93bae318ccee9106494b29cbe79;
        bytes32 root = 0x248ca4fec63d52d29430f99e5c769955dfb2a3ec509cc1593401187d3487e370;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: root,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        vm.prank(dealCreatorAddress);
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            getDealConfig(),
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        vm.expectRevert("purchasing more than allowance");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 300000000000000000001, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_InvalidMerkleProof() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;
        merkleData.account = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        merkleData.index = 0;
        merkleData.amount = 1900000000000000000000;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0x81be000bb7ed07a2c13402cf256a2d1e6b2961edba12560b24789aa434fd0511;
        merkleData.merkleProof[1] = 0xc4f80bb918ef5e099536eccc61682977f69bf93bae318ccee9106494b29cbe79;
        bytes32 root = 0x248ca4fec63d52d29430f99e5c769955dfb2a3ec509cc1593401187d3487e370;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), false);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: root,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        vm.prank(dealCreatorAddress);
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            getDealConfig(),
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        vm.expectRevert("MerkleTree.sol: Invalid proof.");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 100, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_RevertWhen_UseOtherWalletMerkleAllowance(address _user) public {
        vm.assume(_user != address(0xE9bD9f77b864F658F3D1b807157B994fCd52B50B));
        vm.assume(_user != address(0));
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;

        merkleData.account = 0xE9bD9f77b864F658F3D1b807157B994fCd52B50B;
        merkleData.index = 2;
        merkleData.amount = 400000000000000000000;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0x138553c9e25918e18502e13cf0a8886827188bf9f8ca07d864cb5e9ed0e5d86a;
        merkleData.merkleProof[1] = 0x0a63a7efd99b0a48c1f4fa236bac555e316cff73519eeb0aee99a2787338385a;
        bytes32 root = 0x248ca4fec63d52d29430f99e5c769955dfb2a3ec509cc1593401187d3487e370;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: root,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        vm.prank(dealCreatorAddress);
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            getDealConfig(),
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        vm.expectRevert("cant purchase others tokens");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 101, 0);
        vm.stopPrank();
    }

    function test_AcceptDeal_RevertWhen_AlreadyPurchasedMerkleAllownce() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;
        merkleData.account = 0xFF3f759B7ae44Cd75f6A9F714c9E1F4c6950D2aC;
        merkleData.index = 3;
        merkleData.amount = 200000000000000000000;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0x4d56183792276acd6b880733777be91e3476ed1c68e36c8a8355b61e64b49331;
        merkleData.merkleProof[1] = 0x0a63a7efd99b0a48c1f4fa236bac555e316cff73519eeb0aee99a2787338385a;
        bytes32 root = 0x248ca4fec63d52d29430f99e5c769955dfb2a3ec509cc1593401187d3487e370;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: root,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        vm.prank(dealCreatorAddress);
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            getDealConfig(),
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 100, 0);
        vm.expectRevert("Already purchased tokens");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 100, 0);
        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_NoDeallocation(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount <= raiseAmount);
        uint256 firstPurchase = _purchaseAmount / 4;
        uint256 secondPurchase = firstPurchase;
        uint256 thirdPurchase = _purchaseAmount - firstPurchase - secondPurchase;

        // we compute the numbers for the first deposit
        uint256 poolSharesAmount = (firstPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, firstPurchase, firstPurchase, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, firstPurchase, 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1, 0), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1, 0), firstPurchase);

        // we compute the numbers for the second deposit (same user)
        uint256 poolSharesAmount2 = (secondPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            0,
            secondPurchase,
            firstPurchase + secondPurchase,
            poolSharesAmount2,
            poolSharesAmount + poolSharesAmount2
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, secondPurchase, 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(), poolSharesAmount + poolSharesAmount2);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1, 0),
            poolSharesAmount + poolSharesAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), firstPurchase + secondPurchase);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1, 0),
            firstPurchase + secondPurchase
        );

        // now with do the same but for a new user
        vm.stopPrank();
        vm.startPrank(user2);
        uint256 poolSharesAmount3 = (thirdPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, 0, thirdPurchase, thirdPurchase, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, thirdPurchase, 0);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(),
            poolSharesAmount + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user2, 0), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(),
            firstPurchase + secondPurchase + thirdPurchase
        );
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user2, 0), thirdPurchase);

        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_AllowDeallocation(
        uint256 _firstPurchase,
        uint256 _secondPurchase,
        uint256 _thirdPurchase
    ) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(
            0
        );
        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_firstPurchase > 0);
        vm.assume(_secondPurchase > 0);
        vm.assume(_thirdPurchase > 0);
        vm.assume(_firstPurchase < 1e50);
        vm.assume(_secondPurchase < 1e50);
        vm.assume(_thirdPurchase < 1e50);

        vm.assume(_firstPurchase + _secondPurchase + _thirdPurchase > raiseAmount);

        // we compute the numbers for the first deposit
        uint256 poolSharesAmount = (_firstPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, _firstPurchase, _firstPurchase, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _firstPurchase, 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1, 0), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1, 0), _firstPurchase);

        // we compute the numbers for the second deposit (same user)
        uint256 poolSharesAmount2 = (_secondPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            0,
            _secondPurchase,
            _firstPurchase + _secondPurchase,
            poolSharesAmount2,
            poolSharesAmount + poolSharesAmount2
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _secondPurchase, 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount + poolSharesAmount2);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1, 0),
            poolSharesAmount + poolSharesAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _firstPurchase + _secondPurchase);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1, 0),
            _firstPurchase + _secondPurchase
        );

        // now with do the same but for a new user
        vm.stopPrank();
        vm.startPrank(user2);
        uint256 poolSharesAmount3 = (_thirdPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, 0, _thirdPurchase, _thirdPurchase, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _thirdPurchase, 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(),
            poolSharesAmount + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2, 0), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _firstPurchase + _secondPurchase + _thirdPurchase
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2, 0), _thirdPurchase);

        vm.stopPrank();
    }

    function testFuzz_AcceptDeal_AllowList(
        uint256 _purchaseAmount1,
        uint256 _purchaseAmount2,
        uint256 _purchaseAmount3
    ) public {
        uint256 tempAllocatedAmount;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user1);
        vm.assume(_purchaseAmount1 <= tempAllocatedAmount);
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user2);
        vm.assume(_purchaseAmount2 <= tempAllocatedAmount);
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user3);
        vm.assume(_purchaseAmount3 <= tempAllocatedAmount);

        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowList).getVestingScheduleDetails(0);
        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount1 > 0);
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);
        uint256 poolSharesAmount3 = (_purchaseAmount3 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        // first user deposit
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1, 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user1, 0), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user1, 0), _purchaseAmount1);
        vm.stopPrank();

        // second user deposit
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, 0, _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2, 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1 + poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user2, 0), poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1 + _purchaseAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user2, 0), _purchaseAmount2);
        vm.stopPrank();

        // third user deposit
        vm.startPrank(user3);
        deal(address(purchaseToken), user3, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user3, 0, _purchaseAmount3, _purchaseAmount3, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount3, 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(),
            poolSharesAmount1 + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user3, 0), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2 + _purchaseAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user3, 0), _purchaseAmount3);
        vm.stopPrank();
    }

    function test_AcceptDeal_ERC721() public {
        // user setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNftGating721).getVestingScheduleDetails(0);

        MockERC721(collection721_1).mint(user1, 1);
        MockERC721(collection721_1).mint(user1, 2);
        MockERC721(collection721_1).mint(user1, 3);
        MockERC721(collection721_1).mint(user2, 4);
        MockERC721(collection721_1).mint(user2, 5);
        MockERC721(collection721_2).mint(user2, 1);
        MockERC721(collection721_2).mint(user2, 2);
        MockERC721(collection721_2).mint(user2, 3);

        uint256 totalPoolShares;
        uint256 poolSharesAmount;

        // nft gating setup
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // we get the allocation for each collection
        (uint256 purchaseCollection1, , , , ) = AelinUpFrontDeal(dealAddressNftGating721).getNftCollectionDetails(
            address(collection721_1)
        );
        (uint256 purchaseCollection2, , , , ) = AelinUpFrontDeal(dealAddressNftGating721).getNftCollectionDetails(
            address(collection721_2)
        );

        // checks pre-purchase
        bool NftIdUsed;
        bool hasNftList;
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 1);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 2);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 3);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 4);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 5);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 1);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 2);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 3);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        // case 1: [collection1] user1 max out their allocation with multiple tokens (purchaseAmountPerToken = true)
        vm.startPrank(user1);

        // 2 tokens so double the purchaseAmount
        poolSharesAmount = ((2 * purchaseCollection1) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.assume(poolSharesAmount > 0);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, (2 * purchaseCollection1), (2 * purchaseCollection1), poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1), 0);

        // user1 now purchases again using his last token
        poolSharesAmount = (purchaseCollection1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares += poolSharesAmount;
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](1);
        tokenIdsArray[0] = 3;
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            0,
            purchaseCollection1,
            (2 * purchaseCollection1) + purchaseCollection1,
            poolSharesAmount,
            totalPoolShares
        );
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection1, 0);
        vm.stopPrank();

        // case 2: [collection2] user2 max out their wallet allocation (purchaseAmountPerToken = false)
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](3);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        tokenIdsArray[2] = 3;
        nftPurchaseList[0].collectionAddress = address(collection721_2);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        // balance(user2) * purchaseCollection2 as user2 can't buy more than the allocation amount for collection2
        vm.expectRevert("purchase amount greater than max");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, 6 * purchaseCollection2, 0);

        // we then make user2 buy the exact amount
        poolSharesAmount = (purchaseCollection2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, 0, purchaseCollection2, purchaseCollection2, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection2, 0);

        // user2 can't reuse the same tokens if they want to purchase again
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection2, 0);

        // case 3: [collection1] user2 comes back and max out their allocation (purchaseAmountPerToken = true)
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 4;
        tokenIdsArray[1] = 5;
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        // 2 tokens so double the purchaseAmount
        poolSharesAmount = ((2 * purchaseCollection1) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user2,
            0,
            (2 * purchaseCollection1),
            (2 * purchaseCollection1 + purchaseCollection2),
            poolSharesAmount,
            poolSharesAmount + totalPoolShares
        );
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1), 0);

        // user2 can't reuse the same tokens if they want to purchase again
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1), 0);
        vm.stopPrank();

        //checks post-purchase
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 1);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 2);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 3);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 4);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_1), 5);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 1);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 2);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(collection721_2), 3);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function test_AcceptDeal_ERC1155() public {
        // nft gating setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNftGating1155).getVestingScheduleDetails(0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);

        // we mint some tokens
        MockERC1155(address(collection1155_1)).mint(user1, 1, 100, "");
        MockERC1155(address(collection1155_1)).mint(user1, 2, 100, "");
        MockERC1155(address(collection1155_2)).mint(user1, 10, 1000, "");
        MockERC1155(address(collection1155_2)).mint(user1, 20, 2000, "");

        // [collection4] user1 max out their allocation with the 2 collections
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);

        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;

        nftPurchaseList[1].collectionAddress = address(collection1155_2);
        nftPurchaseList[1].tokenIds = new uint256[](2);
        nftPurchaseList[1].tokenIds[0] = 10;
        nftPurchaseList[1].tokenIds[1] = 20;

        //These values used to be maximum purchase allocations, but that logic no longer exists
        uint256 purchaseCollection1 = 1e20;
        uint256 purchaseCollection2 = 1e22;

        // both collections are per token - per wallet removed
        // (balanceOf(tokens) * allocationCollection1) + (balanceOf(tokens) * allocationCollection2)
        uint256 purchaseAmount = (200 * purchaseCollection1) + (3000 * purchaseCollection2);
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        // user1 buys the tokens
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount, 0);

        // we mint new tokens for both collections
        MockERC1155(address(collection1155_1)).mint(user1, 1, 100, "");
        MockERC1155(address(collection1155_2)).mint(user1, 20, 2000, "");

        // if we only use collection 1, it is working because allocation is per new token
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        uint256 newPurchaseAmount = 100 * purchaseCollection1;
        uint256 newPoolShareAmount = (newPurchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            0,
            newPurchaseAmount,
            purchaseAmount + newPurchaseAmount,
            newPoolShareAmount,
            newPoolShareAmount + poolSharesAmount
        );
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, newPurchaseAmount, 0);

        // if we only use collection 2, it reverts
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 20;

        // checks post-purchase
        (bool NftIdUsed, bool hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collection1155_1),
            1
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collection1155_1),
            2
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collection1155_2),
            10
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collection1155_2),
            20
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);

        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPoolShares(), newPoolShareAmount + poolSharesAmount);
        assertEq(
            AelinUpFrontDeal(dealAddressNftGating1155).poolSharesPerUser(user1, 0),
            newPoolShareAmount + poolSharesAmount
        );
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPurchasingAccepted(), purchaseAmount + newPurchaseAmount);
        assertEq(
            AelinUpFrontDeal(dealAddressNftGating1155).purchaseTokensPerUser(user1, 0),
            purchaseAmount + newPurchaseAmount
        );

        vm.stopPrank();
    }

    function test_AcceptDeal_ERC721IdRanges() public {
        // user setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNftGating721IdRanges)
            .getVestingScheduleDetails(0);

        MockERC721(collection721_1).mint(user1, 1);
        MockERC721(collection721_1).mint(user1, 2);
        MockERC721(collection721_1).mint(user1, 3);

        uint256 totalPoolShares;
        uint256 poolSharesAmount;

        // nft gating setup
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // we get the allocation for each collection
        (uint256 purchaseCollection1, , , , ) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftCollectionDetails(
            address(collection721_1)
        );

        // checks pre-purchase
        bool NftIdUsed;
        bool hasNftList;
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1
        );
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            2
        );
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        vm.startPrank(user1);

        poolSharesAmount = (purchaseCollection1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.assume(poolSharesAmount > 0);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721IdRanges), type(uint256).max);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 3;
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        //Second token Id out of range should fail
        vm.expectRevert("tokenId not in range");
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            purchaseCollection1,
            0
        );

        //Second token Id in range should succeed
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, purchaseCollection1, purchaseCollection1, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            purchaseCollection1,
            0
        );
        vm.stopPrank();

        //checks post-purchase
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            2
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function test_AcceptDeal_ERC721IdRanges_Multiple() public {
        // user setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNftGating721IdRanges)
            .getVestingScheduleDetails(0);

        MockERC721(collection721_1).mint(user1, 1e20);
        MockERC721(collection721_1).mint(user1, 1e20 + 1);
        MockERC721(collection721_1).mint(user1, 1e20 + 2);

        uint256 totalPoolShares;
        uint256 poolSharesAmount;

        // nft gating setup
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](3);
        // we get the allocation for each collection
        (uint256 purchaseCollection1, , , , ) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftCollectionDetails(
            address(collection721_1)
        );

        // checks pre-purchase
        bool NftIdUsed;
        bool hasNftList;
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20
        );
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20 + 1
        );
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20 + 2
        );
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        vm.startPrank(user1);

        //Three NFTs in range, so 3 times the allocation
        poolSharesAmount = ((3 * purchaseCollection1) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.assume(poolSharesAmount > 0);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721IdRanges), type(uint256).max);
        tokenIdsArray[0] = 1e20;
        tokenIdsArray[1] = 1e20 + 1;
        tokenIdsArray[2] = 1e20 + 2;
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, (3 * purchaseCollection1), (3 * purchaseCollection1), poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            (3 * purchaseCollection1),
            0
        );
        vm.stopPrank();

        //checks post-purchase
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20 + 1
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(
            address(collection721_1),
            1e20 + 2
        );
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function testFuzz_AcceptDeal_MultipleVestingSchedules(uint256 _purchaseAmount1, uint256 _purchaseAmount2) public {
        vm.assume(_purchaseAmount1 > 0);
        vm.assume(_purchaseAmount2 > 0);

        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();

        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressMultipleVestingSchedules).dealConfig();
        (uint256 purchaseTokenPerDealToken1, , ) = AelinUpFrontDeal(dealAddressMultipleVestingSchedules)
            .getVestingScheduleDetails(0);
        (uint256 purchaseTokenPerDealToken2, , ) = AelinUpFrontDeal(dealAddressMultipleVestingSchedules)
            .getVestingScheduleDetails(1);

        uint256 raiseAmount1 = (underlyingDealTokenTotal * purchaseTokenPerDealToken1) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount1 <= raiseAmount1);
        uint256 raiseAmount2 = (underlyingDealTokenTotal * purchaseTokenPerDealToken2) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount2 <= raiseAmount2);

        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken1;
        vm.assume(poolSharesAmount1 > 0);
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken2;
        vm.assume(poolSharesAmount2 > 0);

        //Accept deal with first vesting schedule and price
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressMultipleVestingSchedules), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressMultipleVestingSchedules).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            _purchaseAmount1,
            0
        );
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).totalPoolShares(), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).poolSharesPerUser(user1, 0), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).purchaseTokensPerUser(user1, 0), _purchaseAmount1);

        //Then second with different schedule and price
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 1, _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressMultipleVestingSchedules).acceptDeal(
            nftPurchaseList,
            merkleDataEmpty,
            _purchaseAmount2,
            1
        );
        assertEq(
            AelinUpFrontDeal(dealAddressMultipleVestingSchedules).totalPoolShares(),
            poolSharesAmount1 + poolSharesAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).poolSharesPerUser(user1, 1), poolSharesAmount2);
        assertEq(
            AelinUpFrontDeal(dealAddressMultipleVestingSchedules).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressMultipleVestingSchedules).purchaseTokensPerUser(user1, 1), _purchaseAmount2);

        vm.stopPrank();
    }

    function test_AcceptDeal_MerkleAllowance() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;
        merkleData.account = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        merkleData.index = 0;
        merkleData.amount = 100000000000000000000;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0x81be000bb7ed07a2c13402cf256a2d1e6b2961edba12560b24789aa434fd0511;
        merkleData.merkleProof[1] = 0xc4f80bb918ef5e099536eccc61682977f69bf93bae318ccee9106494b29cbe79;
        bytes32 root = 0x248ca4fec63d52d29430f99e5c769955dfb2a3ec509cc1593401187d3487e370;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: root,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });

        // create deal
        vm.prank(dealCreatorAddress);
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            getDealConfig(),
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();

        // user accepts deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(merkleDealAddress).getVestingScheduleDetails(0);
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);

        uint256 poolSharesAmount = (100 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user, 0, 100, 100, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 100, 0);
        assertEq(AelinUpFrontDeal(merkleDealAddress).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(merkleDealAddress).poolSharesPerUser(user, 0), poolSharesAmount);
        assertEq(AelinUpFrontDeal(merkleDealAddress).totalPurchasingAccepted(), 100);
        assertEq(AelinUpFrontDeal(merkleDealAddress).purchaseTokensPerUser(user, 0), 100);
        vm.stopPrank();
    }
}
