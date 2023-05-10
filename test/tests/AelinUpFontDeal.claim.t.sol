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
import {IAelinVestingToken} from "contracts/interfaces/IAelinVestingToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MerkleTree} from "contracts/libraries/MerkleTree.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AelinUpFrontDealClaimTest is Test, AelinTestUtils, IAelinUpFrontDeal, IAelinVestingToken {
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
    address dealAddressNoVestingPeriod;
    address dealAddressLowDecimals;
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

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfigNoVestingPeriod = getDealConfig();
        dealConfigNoVestingPeriod.vestingSchedules[0].vestingPeriod = 0;

        IAelinUpFrontDeal.UpFrontDealData memory dealDataLowDecimals = getDealData();
        dealDataLowDecimals.underlyingDealToken = address(underlyingDealTokenLowDecimals);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

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

        dealAddressNoVestingPeriod = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigNoVestingPeriod,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressLowDecimals = upFrontDealFactory.createUpFrontDeal(
            dealDataLowDecimals,
            dealConfig,
            nftCollectionRulesEmpty,
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

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoVestingPeriod), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoVestingPeriod).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealTokenLowDecimals), dealHolderAddress, type(uint256).max);
        underlyingDealTokenLowDecimals.approve(address(dealAddressLowDecimals), type(uint256).max);
        AelinUpFrontDeal(dealAddressLowDecimals).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating1155).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressMultipleVestingSchedules), type(uint256).max);
        AelinUpFrontDeal(dealAddressMultipleVestingSchedules).depositUnderlyingTokens(1e35);

        vm.stopPrank();
    }

    // Helpers
    function getUpFrontDealFuzzed(
        uint256 _purchaseAmount,
        bool _allowDeallocation,
        UpFrontDealVars memory _dealVars
    ) public returns (FuzzedUpFrontDeal memory) {
        vm.assume(_purchaseAmount > 0 && _purchaseAmount < 1000000 * BASE);

        AelinAllowList.InitData memory allowListInitEmpty;

        FuzzedUpFrontDeal memory fuzzed = getFuzzedDeal(
            _dealVars.sponsorFee,
            _dealVars.underlyingDealTokenTotal,
            _dealVars.purchaseTokenPerDealToken,
            _dealVars.purchaseRaiseMinimum,
            _dealVars.purchaseDuration,
            _dealVars.vestingPeriod,
            _dealVars.vestingCliffPeriod,
            _dealVars.purchaseTokenDecimals,
            _dealVars.underlyingTokenDecimals
        );

        fuzzed.dealConfig.allowDeallocation = _allowDeallocation;

        vm.prank(dealCreatorAddress);
        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            fuzzed.dealData,
            fuzzed.dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        fuzzed.upFrontDeal = AelinUpFrontDeal(upfrontDealAddress);

        vm.startPrank(dealHolderAddress);
        deal(fuzzed.dealData.underlyingDealToken, dealHolderAddress, type(uint256).max);
        MockERC20(fuzzed.dealData.underlyingDealToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.depositUnderlyingTokens(_dealVars.underlyingDealTokenTotal);
        vm.stopPrank();

        // Avoid "purchase amount too small"
        vm.assume(_purchaseAmount > _dealVars.purchaseTokenPerDealToken / (10 ** _dealVars.underlyingTokenDecimals));

        return fuzzed;
    }

    /*//////////////////////////////////////////////////////////////
                            purchaserClaim()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchaserClaim_RevertWhen_IncorrectWindow(address _user) public {
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaserClaim(0);
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim(0);
        vm.stopPrank();
    }

    function testFuzz_PurchaserClaim_RevertWhen_NoShares(address _user) public {
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("no pool shares to claim with");
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim(0);
        vm.stopPrank();
    }

    // Does not meet purchaseRaiseMinimum
    function testFuzz_PurchaserClaim_FullRefund(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals,
        uint256 _purchaseAmount
    ) public {
        UpFrontDealVars memory dealVars = boundUpFrontDealVars(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _purchaseTokenDecimals,
            _underlyingTokenDecimals
        );

        vm.assume(_purchaseAmount < dealVars.purchaseRaiseMinimum);

        FuzzedUpFrontDeal memory fuzzed = getUpFrontDealFuzzed(_purchaseAmount, true, dealVars);

        // user1 accepts the deal with _purchaseAmount < purchaseRaiseMinimum
        vm.startPrank(user1);

        deal(address(fuzzed.dealData.purchaseToken), user1, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);

        uint256 poolSharesAmount = (_purchaseAmount * 10 ** dealVars.underlyingTokenDecimals) /
            dealVars.purchaseTokenPerDealToken;

        vm.expectEmit(true, true, true, true);
        emit AcceptDeal(user1, 0, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseListEmpty, merkleDataEmpty, _purchaseAmount, 0);
        assertEq(fuzzed.upFrontDeal.totalPurchasingAccepted(), _purchaseAmount);
        assertEq(fuzzed.upFrontDeal.purchaseTokensPerUser(user1, 0), _purchaseAmount);
        assertEq(IERC20(fuzzed.dealData.purchaseToken).balanceOf(user1), type(uint256).max - _purchaseAmount);

        // purchase period is over, user1 tries to claim and gets a refund instead
        vm.warp(dealVars.purchaseDuration + 2);
        vm.expectEmit(true, true, true, true);
        emit ClaimDealTokens(user1, 0, _purchaseAmount);
        fuzzed.upFrontDeal.purchaserClaim(0);
        assertEq(IERC20(fuzzed.dealData.purchaseToken).balanceOf(user1), type(uint256).max);

        vm.stopPrank();
    }

    function testFuzz_PurchaserClaim_NoDeallocation(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals,
        uint256 _purchaseAmount
    ) public {
        UpFrontDealVars memory dealVars = boundUpFrontDealVars(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _purchaseTokenDecimals,
            _underlyingTokenDecimals
        );

        FuzzedUpFrontDeal memory fuzzed = getUpFrontDealFuzzed(_purchaseAmount, false, dealVars);

        uint256 poolSharesAmount = (_purchaseAmount * 10 ** dealVars.underlyingTokenDecimals) /
            dealVars.purchaseTokenPerDealToken;

        vm.assume(_purchaseAmount > dealVars.purchaseRaiseMinimum);
        vm.assume(poolSharesAmount <= dealVars.underlyingDealTokenTotal);

        // user1 accepts the deal with _purchaseAmount > purchaseRaiseMinimum
        vm.startPrank(user1);

        deal(address(fuzzed.dealData.purchaseToken), user1, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit AcceptDeal(user1, 0, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseListEmpty, merkleDataEmpty, _purchaseAmount, 0);
        assertEq(fuzzed.upFrontDeal.totalPurchasingAccepted(), _purchaseAmount);
        assertEq(fuzzed.upFrontDeal.purchaseTokensPerUser(user1, 0), _purchaseAmount);
        assertEq(IERC20(fuzzed.dealData.purchaseToken).balanceOf(user1), type(uint256).max - _purchaseAmount);

        // purchase period is over and user1 tries to claim
        vm.warp(dealVars.purchaseDuration + 2);
        assertEq(fuzzed.upFrontDeal.poolSharesPerUser(user1, 0), poolSharesAmount);
        uint256 adjustedShareAmountForUser = ((BASE - AELIN_FEE - dealVars.sponsorFee) * poolSharesAmount) / BASE;
        uint256 tokenCount = fuzzed.upFrontDeal.tokenCount();
        vm.expectEmit(true, true, true, true);
        emit VestingTokenMinted(user1, tokenCount, adjustedShareAmountForUser, dealVars.purchaseDuration + 1, 0);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser, 0);
        fuzzed.upFrontDeal.purchaserClaim(0);

        vm.stopPrank();
    }

    function testFuzz_PurchaserClaim_AllowDeallocation(uint256 _purchaseAmount1, uint256 _purchaseAmount2) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(
            0
        );
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.assume(_purchaseAmount1 > 0);
        vm.assume(_purchaseAmount2 > 0);
        vm.assume(_purchaseAmount1 < 1e40);
        vm.assume(_purchaseAmount2 < 1e40);
        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount1 > 0);
        vm.assume(poolSharesAmount2 > 0);
        vm.assume(poolSharesAmount1 + poolSharesAmount2 > underlyingDealTokenTotal);

        // user1 accepts the deal
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1, 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1, 0), _purchaseAmount1);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount1);
        vm.stopPrank();

        // user2 accepts the deal
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, 0, _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2, 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2, 0), _purchaseAmount2);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user2), type(uint256).max - _purchaseAmount2);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user1 tries to claim
        vm.startPrank(user1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1, 0), poolSharesAmount1);
        uint256 adjustedShareAmountForUser1 = (((poolSharesAmount1 * underlyingDealTokenTotal) /
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares()) * (BASE - AELIN_FEE - sponsorFee)) / BASE;
        uint256 refundAmount = _purchaseAmount1 -
            ((_purchaseAmount1 * underlyingDealTokenTotal) /
                AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares());
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(), 0);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(
            user1,
            AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(),
            adjustedShareAmountForUser1,
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry(),
            0
        );
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser1, refundAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim(0);
        vm.stopPrank();

        // post claim checks
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount1 + refundAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1, 0), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1, 0), 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(underlyingDealToken.balanceOf(user1), 0);

        // user2 tries to claim
        vm.startPrank(user2);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2, 0), poolSharesAmount2);
        uint256 adjustedShareAmountForUser2 = (((poolSharesAmount2 * underlyingDealTokenTotal) /
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares()) * (BASE - AELIN_FEE - sponsorFee)) / BASE;
        refundAmount =
            _purchaseAmount2 -
            ((_purchaseAmount2 * underlyingDealTokenTotal) /
                AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares());
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(), 1);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(
            user2,
            AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(),
            adjustedShareAmountForUser2,
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry(),
            0
        );
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user2, adjustedShareAmountForUser2, refundAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim(0);
        vm.stopPrank();

        // post claim checks
        assertEq(IERC20(address(purchaseToken)).balanceOf(user2), type(uint256).max - _purchaseAmount2 + refundAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2, 0), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2, 0), 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(underlyingDealToken.balanceOf(user2), 0);

        // checks if user1 got their vesting token
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user1), 1);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1);
        (uint256 userShare, uint256 lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        assertEq(userShare, adjustedShareAmountForUser1);
        assertEq(lastClaimedAt, AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry());

        // checks if user2 got their vesting token
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user2), 1);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(1), user2);
        (userShare, lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(1);
        assertEq(userShare, adjustedShareAmountForUser2);
        assertEq(lastClaimedAt, AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry());
    }

    /*//////////////////////////////////////////////////////////////
                            sponsorClaim()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SponsorClaim_RevertWhen_NotInWindow(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).sponsorClaim(0);
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim(0);
        vm.stopPrank();
    }

    function testFuzz_SponsorClaim_RevertWhen_NotReachedMininumRaise(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseRaiseMinimum, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        vm.assume(_purchaseAmount > 0);
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount < purchaseMinimum
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        console.logUint(_purchaseAmount);
        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim(0);
        vm.stopPrank();

        // sponsor tries to call sponsorClaim() and it reverts
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim(0);
        vm.stopPrank();
    }

    function testFuzz_SponsorClaim_RevertWhen_NotSponsor(uint256 _purchaseAmount) public {
        // user accepts the deal with purchaseAmount >= purchaseMinimum
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(address(dealAddressAllowDeallocation), _purchaseAmount, user1, true);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("must be sponsor");
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim(0);
        vm.stopPrank();
    }

    function testFuzz_SponsorClaim_RevertWhen_AlreadyClaimed(uint256 _purchaseAmount) public {
        // user accepts the deal with purchaseAmount >= purchaseMinimum
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(address(dealAddressAllowDeallocation), _purchaseAmount, user1, true);
        vm.stopPrank();
        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // sponsor now claims
        vm.startPrank(dealCreatorAddress);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim(0);

        // sponsor tries to claim again and it fails
        vm.expectRevert("sponsor already claimed");
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim(0);
        vm.stopPrank();
    }

    function testFuzz_SponsorClaim_NoDeallocation(uint256 _purchaseAmount) public {
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();

        // user1 accepts the deal
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(address(dealAddressNoDeallocation), _purchaseAmount, user1);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(purchaseExpiry + 1 days);

        // sponsor now claims and gets a vesting token
        vm.startPrank(dealCreatorAddress);
        uint256 tokenCount = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        uint256 totalSold = AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares();
        uint256 shareAmount = (totalSold * sponsorFee) / BASE;
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(dealCreatorAddress, tokenCount, shareAmount, purchaseExpiry, 0);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(dealCreatorAddress, shareAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim(0);
        vm.stopPrank();
    }

    function testFuzz_SponsorClaim_AllowDeallocation(uint256 _purchaseAmount) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();

        // user1 accepts the deal
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(address(dealAddressAllowDeallocation), _purchaseAmount, user1, true);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(purchaseExpiry + 1 days);

        // sponsor now claims and gets a vesting token
        vm.startPrank(dealCreatorAddress);
        uint256 tokenCount = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        uint256 shareAmount = (underlyingDealTokenTotal * sponsorFee) / BASE;
        console.logUint(shareAmount);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(dealCreatorAddress, tokenCount, shareAmount, purchaseExpiry, 0);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(dealCreatorAddress, shareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim(0);
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0));
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            holderClaim()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_HolderClaim_RevertWhen_NotInWindow(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).holderClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    function testFuzz_HolderClaim_RevertWhen_NotHolder(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        // user accepts the deal
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, false);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    function testFuzz_HolderClaim_RevertWhen_AlreadyClaimed(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(
            0
        );
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, false);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // holder calls holderClaim()
        vm.startPrank(dealHolderAddress);
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();

        // holder calls holderClaim() again and it reverts
        vm.expectRevert("holder already claimed");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    function testFuzz_HolderClaim_NotReachedMinimumRaise(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseRaiseMinimum, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount < purchaseMinimum
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // holder tries to call sponsorClaim() and gets all their underlying deal tokens back
        vm.startPrank(dealHolderAddress);
        uint256 amountRefund = underlyingDealToken.balanceOf(address(dealAddressNoDeallocation));
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            0,
            address(underlyingDealToken),
            amountRefund,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).holderClaim();
        uint256 amountAfterClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        assertEq(amountAfterClaim - amountBeforeClaim, amountRefund);
        vm.stopPrank();
    }

    function testFuzz_HolderClaim_NoDeallocation(uint256 _purchaseAmount) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();

        // user accepts the deal with purchaseMinimum  < purchaseAmount < deal total
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // holder calls sponsorClaim()
        vm.startPrank(dealHolderAddress);
        uint256 amountRaise = purchaseToken.balanceOf(dealAddressNoDeallocation);
        uint256 amountRefund = underlyingDealTokenTotal -
            AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1, 0);
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 totalPoolShares = AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares();
        uint256 feeAmount = (totalPoolShares * AELIN_FEE) / BASE;
        assertEq(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow()), address(0));
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            amountRaise,
            address(underlyingDealToken),
            underlyingDealTokenTotal - totalPoolShares,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).holderClaim();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress) - amountBeforeClaim, amountRefund);
        // this function also calls the claim for the protocol fee
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    function testFuzz_HolderClaim_AllowDeallocation(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(
            0
        );

        // user accepts the deal with purchaseAmount > deal total
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // holder calls sponsorClaim()
        vm.startPrank(dealHolderAddress);
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10 ** underlyingTokenDecimals;
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            totalIntendedRaise,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), amountBeforeClaim);
        // this function also calls the claim for the protocol fee
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            feeEscrowClaim()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_FeeEscrowClaim_RevertWhen_NotInWindow(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).feeEscrowClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressAllowDeallocation).feeEscrowClaim();
        vm.stopPrank();
    }

    function testFuzz_FeeEscrowClaim_RevertWhen_NotReachedMinimumRaise(uint256 _purchaseAmount) public {
        (, uint256 purchaseRaiseMinimum, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.assume(_purchaseAmount > 0);
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user1 accepts the deal with _purchaseAmount < purchaseRaiseMinimum
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, 0, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1, 0), _purchaseAmount);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount);

        // purchase period is over, user1 tries to claim and gets a refund instead
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressNoDeallocation).feeEscrowClaim();

        vm.stopPrank();
    }

    function testFuzz_FeeEscrowClaim_NoDeallocation(uint256 _purchaseAmount) public {
        // user accepts the deal
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // user calls feeEscrowClaim()
        uint256 feeAmount = (AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares() * AELIN_FEE) / BASE;
        assertEq(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow()), address(0));

        AelinUpFrontDeal(dealAddressNoDeallocation).feeEscrowClaim();
        assertTrue(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow()) != address(0));
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow())),
            feeAmount
        );

        vm.stopPrank();
    }

    function testFuzz_FeeEscrowClaim_AllowDeallocation(uint256 _purchaseAmount) public {
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();

        // user accepts the deal with purchaseAmount > deal total
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user calls feeEscrowClaim()
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));

        AelinUpFrontDeal(dealAddressAllowDeallocation).feeEscrowClaim();
        assertTrue(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()) != address(0));
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount,
            "feeAmount"
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        claimableUnderlyingTokens()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimableUnderlyingTokens_NotInWindow(uint256 _tokenId) public {
        vm.startPrank(user1);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).claimableUnderlyingTokens(_tokenId), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(_tokenId), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_WrongTokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        reachVestingPeriod(dealAddressNoDeallocation);
        // user should have something to claim
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        assertGt(AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId), 0);
        // user doesn't have this token, so it reverts
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId + 1), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_QuantityZero(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        // user doesn't have anything to claim since vestingCliff is not over yet
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_DuringVestingCliffPeriod(uint256 _purchaseAmount, uint256 _delay) public {
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiries(0);
        (bool success, ) = SafeMath.tryAdd(purchaseExpiry, _delay);
        vm.assume(success);
        vm.assume(_delay > 0);
        vm.assume(purchaseExpiry + _delay <= vestingCliffExpiry);
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        vm.warp(purchaseExpiry + _delay);
        // user doesn't have anything to claim since vestingCliff is not over yet
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_DuringVestingPeriod(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals,
        uint256 _purchaseAmount,
        uint256 _delay
    ) public {
        UpFrontDealVars memory dealVars = boundUpFrontDealVars(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _purchaseTokenDecimals,
            _underlyingTokenDecimals
        );

        vm.assume(_delay > 0 && _delay < dealVars.vestingPeriod);

        FuzzedUpFrontDeal memory fuzzed = getUpFrontDealFuzzed(_purchaseAmount, false, dealVars);

        uint256 poolSharesAmount = (_purchaseAmount * 10 ** dealVars.underlyingTokenDecimals) /
            dealVars.purchaseTokenPerDealToken;

        vm.assume(_purchaseAmount > dealVars.purchaseRaiseMinimum);
        vm.assume(poolSharesAmount <= dealVars.underlyingDealTokenTotal);

        // user1 accepts the deal with _purchaseAmount > purchaseRaiseMinimum
        vm.startPrank(user1);

        deal(address(fuzzed.dealData.purchaseToken), user1, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseListEmpty, merkleDataEmpty, _purchaseAmount, 0);

        uint256 vestingCliffExpiry = fuzzed.upFrontDeal.vestingCliffExpiries(0);
        vm.warp(vestingCliffExpiry + _delay);

        uint256 vestingTokenId = fuzzed.upFrontDeal.tokenCount();
        uint256 shareAmount = ((BASE - AELIN_FEE - dealVars.sponsorFee) * fuzzed.upFrontDeal.poolSharesPerUser(user1, 0)) /
            BASE;

        fuzzed.upFrontDeal.purchaserClaim(0);
        assertEq(MockERC721(address(fuzzed.upFrontDeal)).ownerOf(vestingTokenId), user1);
        uint256 amountToClaim = (shareAmount * (block.timestamp - vestingCliffExpiry)) / dealVars.vestingPeriod;
        assertEq(fuzzed.upFrontDeal.claimableUnderlyingTokens(vestingTokenId), amountToClaim, "claimableAmount");

        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_AfterVestingPeriod(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals,
        uint256 _purchaseAmount,
        uint256 _delay
    ) public {
        UpFrontDealVars memory dealVars = boundUpFrontDealVars(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _purchaseTokenDecimals,
            _underlyingTokenDecimals
        );

        vm.assume(_delay > dealVars.vestingPeriod && _delay < 1000000 * BASE);

        FuzzedUpFrontDeal memory fuzzed = getUpFrontDealFuzzed(_purchaseAmount, false, dealVars);

        uint256 poolSharesAmount = (_purchaseAmount * 10 ** dealVars.underlyingTokenDecimals) /
            dealVars.purchaseTokenPerDealToken;

        vm.assume(_purchaseAmount > dealVars.purchaseRaiseMinimum);
        vm.assume(poolSharesAmount <= dealVars.underlyingDealTokenTotal);

        // user1 accepts the deal with _purchaseAmount > purchaseRaiseMinimum
        vm.startPrank(user1);

        deal(address(fuzzed.dealData.purchaseToken), user1, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseListEmpty, merkleDataEmpty, _purchaseAmount, 0);

        uint256 vestingCliffExpiry = fuzzed.upFrontDeal.vestingCliffExpiries(0);
        vm.warp(vestingCliffExpiry + _delay);

        uint256 vestingTokenId = fuzzed.upFrontDeal.tokenCount();
        uint256 adjustedShareAmountForUser = ((BASE - AELIN_FEE - dealVars.sponsorFee) *
            fuzzed.upFrontDeal.poolSharesPerUser(user1, 0)) / BASE;

        fuzzed.upFrontDeal.purchaserClaim(0);

        assertEq(MockERC721(address(fuzzed.upFrontDeal)).ownerOf(vestingTokenId), user1);
        assertEq(
            fuzzed.upFrontDeal.claimableUnderlyingTokens(vestingTokenId),
            adjustedShareAmountForUser,
            "claimableAmount"
        );

        vm.stopPrank();
    }

    function testFuzz_ClaimableUnderlyingTokens_NoVestingPeriod(uint256 _purchaseAmount) public {
        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressNoVestingPeriod);
        uint256 vestingCliffExpiry = deal.vestingCliffExpiries(0);

        vm.startPrank(user1);
        // lastClaimedAt is 0
        assertEq(deal.claimableUnderlyingTokens(0), 0, "claimableAmount before accepting");

        // lastClaimedAt > 0
        setupAndAcceptDealNoDeallocation(dealAddressNoVestingPeriod, _purchaseAmount, user1);
        purchaserClaim(dealAddressNoVestingPeriod);

        // Before vesting cliff expiry
        assertEq(deal.claimableUnderlyingTokens(0), 0, "claimableAmount before vesting cliff expiry");

        // After vesting cliff expiry
        vm.warp(vestingCliffExpiry);

        (uint256 share, , ) = deal.vestingDetails(0);

        assertEq(deal.claimableUnderlyingTokens(0), share, "claimableAmount after vesting cliff expiry => all shares");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            claimUnderlying()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimUnderlying_NothingToClaim(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);

        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_RevertWhen_NotVestingTokenOwner(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_user != user1);
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        vm.stopPrank();

        vm.startPrank(_user);
        vm.expectRevert("must be owner to claim");
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_RevertWhen_IncorrectVestingTokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);

        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId + 1);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_VestingCliff(uint256 _purchaseAmount, uint256 _delay) public {
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiries(0);
        (bool success, ) = SafeMath.tryAdd(purchaseExpiry, _delay);
        vm.assume(success);
        vm.assume(_delay > 0);
        vm.assume(purchaseExpiry + _delay <= vestingCliffExpiry);
        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);
        vm.warp(purchaseExpiry + _delay);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_DeallocationVestingPeriod(uint256 _purchaseAmount, uint256 _delay) public {
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingCliffExpiries(0);
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0);
        (, , uint256 vestingPeriod) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(0);
        (bool success, ) = SafeMath.tryAdd(vestingCliffExpiry, _delay);
        vm.assume(success);
        vm.assume(_delay > 0);
        vm.assume(vestingCliffExpiry + _delay < vestingExpiry);

        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(vestingTokenId), user1);

        // we are now in the vesting window and user can claim
        vm.warp(vestingCliffExpiry + _delay);
        vm.expectEmit(true, false, false, true);
        (uint256 shareAmount, uint256 lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(
            vestingTokenId
        );
        uint256 amountToClaim = (shareAmount * (block.timestamp - vestingCliffExpiry)) / vestingPeriod;
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), amountToClaim);
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), amountToClaim, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalUnderlyingClaimed(),
            amountToClaim,
            "totalUnderlyingClaimed"
        );

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (shareAmount, lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(vestingTokenId);
        assertEq(lastClaimedAt, vestingCliffExpiry + _delay, "lastClaimedAt");
        uint256 amountToClaim2 = (shareAmount * (vestingExpiry - lastClaimedAt)) / vestingPeriod;
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), amountToClaim2);
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), amountToClaim + amountToClaim2, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalUnderlyingClaimed(),
            amountToClaim + amountToClaim2,
            "totalUnderlyingClaimed"
        );

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).claimableUnderlyingTokens(vestingTokenId),
            0,
            "claimableUnderlyingTokens"
        );
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);

        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_NoDeallocationVestingPeriod(uint256 _purchaseAmount, uint256 _delay) public {
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiries(0);
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiries(0);
        (, , uint256 vestingPeriod) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        (bool success, ) = SafeMath.tryAdd(vestingCliffExpiry, _delay);
        vm.assume(success);
        vm.assume(_delay > 0);
        vm.assume(vestingCliffExpiry + _delay < vestingExpiry);

        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);

        // we are now in the vesting window and user can claim
        vm.warp(vestingCliffExpiry + _delay);
        vm.expectEmit(true, false, false, true);
        (uint256 shareAmount, uint256 lastClaimedAt, ) = AelinUpFrontDeal(dealAddressNoDeallocation).vestingDetails(
            vestingTokenId
        );
        uint256 amountToClaim = (shareAmount * (block.timestamp - vestingCliffExpiry)) / vestingPeriod;
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), amountToClaim);
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), amountToClaim, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalUnderlyingClaimed(),
            amountToClaim,
            "totalUnderlyingClaimed"
        );

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (shareAmount, lastClaimedAt, ) = AelinUpFrontDeal(dealAddressNoDeallocation).vestingDetails(vestingTokenId);
        assertEq(lastClaimedAt, vestingCliffExpiry + _delay, "lastClaimedAt");
        uint256 amountToClaim2 = (shareAmount * (vestingExpiry - lastClaimedAt)) / vestingPeriod;
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), amountToClaim2);
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), amountToClaim + amountToClaim2, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalUnderlyingClaimed(),
            amountToClaim + amountToClaim2,
            "totalUnderlyingClaimed"
        );

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId),
            0,
            "claimableUnderlyingTokens"
        );
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);

        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_NoDeallocationVestingPeriodLowDecimals(
        uint256 _purchaseAmount,
        uint256 _delay
    ) public {
        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressLowDecimals);

        uint256 vestingCliffExpiry = deal.vestingCliffExpiries(0);
        uint256 vestingExpiry = deal.vestingExpiries(0);
        (, , uint256 vestingPeriod) = deal.getVestingScheduleDetails(0);
        (bool success, ) = SafeMath.tryAdd(vestingCliffExpiry, _delay);
        vm.assume(success);
        vm.assume(_delay > 0);
        vm.assume(vestingCliffExpiry + _delay < vestingExpiry);

        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressLowDecimals, _purchaseAmount, user1);
        uint256 vestingTokenId = deal.tokenCount();
        purchaserClaim(dealAddressLowDecimals);
        assertEq(MockERC721(dealAddressLowDecimals).ownerOf(vestingTokenId), user1);

        // we are now in the vesting window and user can claim
        vm.warp(vestingCliffExpiry + _delay);
        vm.expectEmit(true, false, false, true);
        (uint256 shareAmount, uint256 lastClaimedAt, ) = deal.vestingDetails(vestingTokenId);
        uint256 amountToClaim = (shareAmount * (block.timestamp - vestingCliffExpiry)) / vestingPeriod;
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealTokenLowDecimals), amountToClaim);
        deal.claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealTokenLowDecimals.balanceOf(user1), amountToClaim, "underlyingClaimed");
        assertEq(deal.totalUnderlyingClaimed(), amountToClaim, "totalUnderlyingClaimed");

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (shareAmount, lastClaimedAt, ) = deal.vestingDetails(vestingTokenId);
        assertEq(lastClaimedAt, vestingCliffExpiry + _delay, "lastClaimedAt");
        uint256 amountToClaim2 = (shareAmount * (vestingExpiry - lastClaimedAt)) / vestingPeriod;
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealTokenLowDecimals), amountToClaim2);
        deal.claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealTokenLowDecimals.balanceOf(user1), amountToClaim + amountToClaim2, "underlyingClaimed");
        assertEq(deal.totalUnderlyingClaimed(), amountToClaim + amountToClaim2, "totalUnderlyingClaimed");

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(deal.claimableUnderlyingTokens(vestingTokenId), 0, "claimableUnderlyingTokens");
        vm.expectRevert("ERC721: invalid token ID");
        deal.claimUnderlying(vestingTokenId);

        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_DeallocationVestingEnd(uint256 _purchaseAmount) public {
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0);
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();

        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(vestingTokenId), user1);

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (uint256 shareAmount, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(vestingTokenId);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), shareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), shareAmount, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalUnderlyingClaimed(),
            shareAmount,
            "totalUnderlyingClaimed"
        );

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).claimableUnderlyingTokens(vestingTokenId),
            0,
            "claimableUnderlyingTokens"
        );
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);
        vm.stopPrank();

        // sponsor claims and empty the contract from its underlying deal tokens
        vm.startPrank(dealCreatorAddress);
        uint256 sponsorShareAmount = (underlyingDealTokenTotal * sponsorFee) / BASE;
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(dealCreatorAddress, vestingTokenId + 1, sponsorShareAmount, purchaseExpiry, 0);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(dealCreatorAddress, sponsorShareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim(0);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(
            dealCreatorAddress,
            vestingTokenId,
            address(underlyingDealToken),
            sponsorShareAmount
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId + 1);

        vm.warp(vestingExpiry + 4 days);
        assertEq(underlyingDealToken.balanceOf(dealAddressAllowDeallocation), 0, "underlyingBalance");
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), sponsorShareAmount, "underlyingBalanceSponsor");
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).claimableUnderlyingTokens(vestingTokenId + 1),
            0,
            "claimableUnderlyingTokens"
        );

        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_NoDeallocationVestingEnd(uint256 _purchaseAmount) public {
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiries(0);

        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressNoDeallocation, _purchaseAmount, user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        purchaserClaim(dealAddressNoDeallocation);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(vestingTokenId), user1);

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (uint256 shareAmount, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).vestingDetails(vestingTokenId);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), shareAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealToken.balanceOf(user1), shareAmount, "underlyingClaimed");
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalUnderlyingClaimed(),
            shareAmount,
            "totalUnderlyingClaimed"
        );

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).claimableUnderlyingTokens(vestingTokenId),
            0,
            "claimableUnderlyingTokens"
        );
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNoDeallocation).claimUnderlying(vestingTokenId);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_NoDeallocationVestingEndLowDecimals(uint256 _purchaseAmount) public {
        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressLowDecimals);
        uint256 vestingExpiry = deal.vestingExpiries(0);

        vm.startPrank(user1);
        setupAndAcceptDealNoDeallocation(dealAddressLowDecimals, _purchaseAmount, user1);
        uint256 vestingTokenId = deal.tokenCount();
        purchaserClaim(dealAddressLowDecimals);
        assertEq(MockERC721(dealAddressLowDecimals).ownerOf(vestingTokenId), user1);

        // Second claim after vesting period is over
        vm.warp(vestingExpiry + 1 days);
        (uint256 shareAmount, , ) = deal.vestingDetails(vestingTokenId);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealTokenLowDecimals), shareAmount);
        deal.claimUnderlying(vestingTokenId);

        // after claim checks
        assertEq(underlyingDealTokenLowDecimals.balanceOf(user1), shareAmount, "underlyingClaimed");
        assertEq(deal.totalUnderlyingClaimed(), shareAmount, "totalUnderlyingClaimed");

        // new claim attempt should revert
        vm.warp(vestingExpiry + 2 days);
        assertEq(deal.claimableUnderlyingTokens(vestingTokenId), 0, "claimableUnderlyingTokens");
        vm.expectRevert("ERC721: invalid token ID");
        deal.claimUnderlying(vestingTokenId);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlying_MultipleVestingSchedules(uint256 _purchaseAmount1, uint256 _delay) public {
        vm.assume(_delay > 0);
        vm.assume(_delay < 10 days); // Delta between vestingCliffExpiry1 and vestingCliffExpiry2 is 10 days
        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressMultipleVestingSchedules);

        uint256 vestingCliffExpiry1 = deal.vestingCliffExpiries(0);
        uint256 vestingCliffExpiry2 = deal.vestingCliffExpiries(1);

        // user1 accepts deal across two vesting periods
        vm.startPrank(user1);
        setupAndAcceptDealWithMultipleVesting(dealAddressMultipleVestingSchedules, _purchaseAmount1, user1);

        //User claims vesting tokens, we know that vestingCliffExpiry2 > vestingCliffExpiry1
        vm.warp(vestingCliffExpiry1 - _delay);

        uint256 vestingTokenId1 = deal.tokenCount();
        deal.purchaserClaim(0);
        deal.purchaserClaim(1);

        assertEq(deal.ownerOf(vestingTokenId1), user1);
        assertEq(deal.ownerOf(vestingTokenId1 + 1), user1);

        //before each vesting has finished, claims should get nothing
        assertEq(deal.claimUnderlying(vestingTokenId1), 0);
        assertEq(deal.claimUnderlying(vestingTokenId1 + 1), 0);

        //Then claim 1 will succeed, and two will recieve nothing
        vm.warp(vestingCliffExpiry1 + _delay);
        uint256 claimableUnderlyingTokens1 = deal.claimableUnderlyingTokens(vestingTokenId1);
        assertGt(claimableUnderlyingTokens1, 0);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId1, address(underlyingDealToken), claimableUnderlyingTokens1);
        deal.claimUnderlying(vestingTokenId1);
        assertEq(deal.claimUnderlying(vestingTokenId1 + 1), 0);

        //Then both will start receiving when claining
        vm.warp(vestingCliffExpiry2 + _delay);
        claimableUnderlyingTokens1 = deal.claimableUnderlyingTokens(vestingTokenId1);
        uint256 claimableUnderlyingTokens2 = deal.claimableUnderlyingTokens(vestingTokenId1 + 1);
        assertGt(claimableUnderlyingTokens1, 0);
        assertGt(claimableUnderlyingTokens2, 0);

        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId1, address(underlyingDealToken), claimableUnderlyingTokens1);
        deal.claimUnderlying(vestingTokenId1);

        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(
            user1,
            vestingTokenId1 + 1,
            address(underlyingDealToken),
            claimableUnderlyingTokens2
        );
        deal.claimUnderlying(vestingTokenId1 + 1);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    claimUnderlyingMutlipleEntries()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimUnderlyingMultipleEntries_OneVestingSchedule(uint256 _purchaseAmount1) public {
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0);

        // user1 accepts
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount1, user1, true);
        vm.stopPrank();

        // user2 accepts
        vm.startPrank(user2);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount1, user2, true);
        vm.stopPrank();

        // user1 claims
        vm.startPrank(user1);
        uint256 vestingTokenId = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(vestingTokenId), user1);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1);
        vm.stopPrank();

        // user2 claims
        vm.startPrank(user2);
        vestingTokenId = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(vestingTokenId), user2);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user2), 1);

        // user2 transfers their vesting token to user1
        MockERC721(dealAddressAllowDeallocation).transfer(user1, vestingTokenId, "0x0");
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user2), 0);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 2);

        // user2 tries claiming and it reverts
        // TokenIds
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = vestingTokenId;
        tokenIds[1] = vestingTokenId - 1;
        // Vesting Indices
        uint256[] memory vestingIndices = new uint256[](1);
        vestingIndices[0] = 0;

        vm.expectRevert("must be owner to claim");
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlyingMultipleEntries(tokenIds);
        vm.expectRevert("must be owner to claim");
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(vestingTokenId);
        vm.stopPrank();

        // user1 tries to claiming
        vm.warp(vestingExpiry + 1 days);
        vm.startPrank(user1);
        (uint256 share1, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(vestingTokenId - 1);
        (uint256 share2, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(vestingTokenId);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId - 1, address(underlyingDealToken), share1);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId, address(underlyingDealToken), share2);
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlyingMultipleEntries(tokenIds);
        assertEq(underlyingDealToken.balanceOf(user1), share1 + share2);

        // user1 attempts claiming more the next day but it reverts
        vm.warp(vestingExpiry + 2 days);
        // nothing is claimable, all the tokens have been vested and burned
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).claimableUnderlyingTokens(vestingTokenId - 1), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).claimableUnderlyingTokens(vestingTokenId), 0);
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlyingMultipleEntries(tokenIds), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlyingMultipleEntries_MultipleVestingSchedules(
        uint256 _purchaseAmount1,
        uint256 _delay
    ) public {
        vm.assume(_delay > 0);
        vm.assume(_delay < 10 days); // Delta between vestingCliffExpiry1 and vestingCliffExpiry2 is 10 days
        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressMultipleVestingSchedules);

        uint256 vestingCliffExpiry1 = deal.vestingCliffExpiries(0);
        uint256 vestingCliffExpiry2 = deal.vestingCliffExpiries(1);

        // user1 accepts deal across two vesting periods
        vm.startPrank(user1);
        setupAndAcceptDealWithMultipleVesting(dealAddressMultipleVestingSchedules, _purchaseAmount1, user1);

        //Then claim 1 will succeed, and two will recieve nothing
        vm.warp(vestingCliffExpiry1 + _delay);

        uint256 vestingTokenId1 = deal.tokenCount();
        deal.purchaserClaim(0);
        deal.purchaserClaim(1);

        uint256 claimableUnderlyingTokens1 = deal.claimableUnderlyingTokens(vestingTokenId1);
        uint256 claimableUnderlyingTokens2 = deal.claimableUnderlyingTokens(vestingTokenId1 + 1);
        assertGt(claimableUnderlyingTokens1, 0);
        assertEq(claimableUnderlyingTokens2, 0);

        // TokenIds
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = vestingTokenId1;
        tokenIds[1] = vestingTokenId1 + 1;

        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, vestingTokenId1, address(underlyingDealToken), claimableUnderlyingTokens1);
        deal.claimUnderlyingMultipleEntries(tokenIds);

        //Then both will start receiving when claining
        vm.warp(vestingCliffExpiry2 + _delay);
        claimableUnderlyingTokens1 = deal.claimableUnderlyingTokens(vestingTokenId1);
        claimableUnderlyingTokens2 = deal.claimableUnderlyingTokens(vestingTokenId1 + 1);
        assertGt(claimableUnderlyingTokens1, 0);
        assertGt(claimableUnderlyingTokens2, 0);

        assertEq(deal.claimUnderlyingMultipleEntries(tokenIds), claimableUnderlyingTokens1 + claimableUnderlyingTokens2);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            transfer()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Transfer_RevertWhen_NotOwner(uint256 _purchaseAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1, "vestingTokenOwnerOf");
        vm.stopPrank();

        // user2 tries to transfer the token
        vm.startPrank(user2);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        MockERC721(dealAddressAllowDeallocation).transfer(user3, 0, "0x0");
        vm.stopPrank();
    }

    function testFuzz_Transfer_RevertWhen_WrongTokenId() public {
        // user2 tries to transfer the token
        vm.startPrank(user1);
        vm.expectRevert("ERC721: invalid token ID");
        MockERC721(dealAddressAllowDeallocation).transfer(user2, 0, "0x0");
        vm.stopPrank();
    }

    function testFuzz_Transfer(uint256 _purchaseAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1, "vestingTokenOwnerOf");

        // user1 transfers their token to user2
        (uint256 share, uint256 lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        vm.expectEmit(true, true, true, false);
        emit Transfer(user1, user2, 0);
        AelinUpFrontDeal(dealAddressAllowDeallocation).transfer(user2, 0, "0x0");
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 0, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user2), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user2, "vestingTokenOwnerOf");
        (uint256 shareTemp, uint256 lastClaimedAtTemp, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        assertEq(share, shareTemp, "shareAmount");
        assertEq(lastClaimedAt, lastClaimedAtTemp, "lastClaimedAt");

        // user1 can't transfer the token as they don't own it anymore
        vm.expectRevert("ERC721: transfer from incorrect owner");
        MockERC721(dealAddressAllowDeallocation).transfer(user3, 0, "0x0");
        vm.stopPrank();

        // user2 transfers the token to user3
        vm.startPrank(user2);
        vm.expectEmit(true, true, true, false);
        emit Transfer(user2, user3, 0);
        MockERC721(dealAddressAllowDeallocation).transfer(user3, 0, "0x0");
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user2), 0, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user3), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user3, "vestingTokenOwnerOf");
        (shareTemp, lastClaimedAtTemp, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        assertEq(share, shareTemp, "shareAmount");
        assertEq(lastClaimedAt, lastClaimedAtTemp, "lastClaimedAt");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        transferVestingShare()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TransferVestingShare_RevertWhen_NotOwner(uint256 _purchaseAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1, "vestingTokenOwnerOf");
        vm.stopPrank();

        // user2 tries to transfer the token
        vm.startPrank(user2);
        (uint256 share, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        vm.expectRevert("must be owner to transfer");
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user3, 0, share - 1);
        vm.stopPrank();
    }

    function testFuzz_TransferVestingShare_RevertWhen_WrongTokenId() public {
        // user1 tries to transfer a part of a vesting token share
        vm.startPrank(user1);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user2, 0, 0);
        vm.stopPrank();
    }

    function testFuzz_TransferVestingShare_RevertWhen_ShareAmountIsZero(uint256 _purchaseAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1, "vestingTokenOwnerOf");

        // user1 tries to transfer a part of a vesting token share
        vm.expectRevert("share amount should be > 0");
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user2, 0, 0);
        vm.stopPrank();
    }

    function testFuzz_TransferVestingShare_RevertWhen_ShareAmountTooHigh(uint256 _purchaseAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1, "vestingTokenOwnerOf");

        // user1 tries to transfer an amount greather than the total value of their vesting
        (uint256 share, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        vm.expectRevert("cant transfer more than current share");
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user2, 0, share + 1);
    }

    function testFuzz_TransferVestingShare(uint256 _purchaseAmount, uint256 _shareAmount) public {
        // user1 accepts deal and claim their vesting token
        vm.startPrank(user1);
        setupAndAcceptDealWithDeallocation(dealAddressAllowDeallocation, _purchaseAmount, user1, true);
        uint256 tokenCount = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        purchaserClaim(dealAddressAllowDeallocation);
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(tokenCount), user1, "vestingTokenOwnerOf");
        (uint256 share, uint256 lastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(tokenCount);
        vm.assume(_shareAmount > 0);
        vm.assume(_shareAmount < share);

        // user1 transfers a part of their share to user2
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(user2, tokenCount + 1, _shareAmount, lastClaimedAt, 0);
        vm.expectEmit(true, true, true, false);
        emit VestingShareTransferred(user1, user2, tokenCount, _shareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user2, tokenCount, _shareAmount);

        // user1 still has the same token but with a smaller share
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user1), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(tokenCount), user1, "vestingTokenOwnerOf");
        (uint256 newShare, uint256 newLastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(
            tokenCount
        );
        assertEq(newShare, share - _shareAmount);
        assertEq(newLastClaimedAt, lastClaimedAt);

        // user2 has a new vesting token with a share of user1
        assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user2), 1, "vestingTokenBalance");
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(tokenCount + 1), user2, "vestingTokenOwnerOf");
        (newShare, newLastClaimedAt, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(tokenCount + 1);
        assertEq(newShare, _shareAmount);
        assertEq(newLastClaimedAt, lastClaimedAt);
        vm.stopPrank();

        // vesting is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0) + 1 days);

        // user1 claims all and transfer to user3
        vm.startPrank(user1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user1), 1);
        vm.expectEmit(true, false, false, false);
        emit VestingTokenBurned(tokenCount);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(user1, tokenCount, address(underlyingDealToken), share - _shareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).claimUnderlying(tokenCount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user1), 0);

        // user1 can't transfer because the token has been burned
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiries(0) + 2 days);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressAllowDeallocation).transferVestingShare(user3, tokenCount, (share - _shareAmount) / 2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      Scenarios with precision error
    //////////////////////////////////////////////////////////////*/

    function test_PrecisionError_PurchaserSide() public {
        // Deal config
        vm.startPrank(dealCreatorAddress);
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 0,
            ipfsHash: "",
            merkleRoot: 0
        });

        IAelinUpFrontDeal.VestingSchedule[] memory vestingSchedules = new IAelinUpFrontDeal.VestingSchedule[](1);

        vestingSchedules[0].purchaseTokenPerDealToken = 2e18;
        vestingSchedules[0].vestingCliffPeriod = 1 days;
        vestingSchedules[0].vestingPeriod = 10 days;

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1.5e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 1 days,
            vestingSchedules: vestingSchedules,
            allowDeallocation: true
        });

        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(upfrontDealAddress).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(upfrontDealAddress).getVestingScheduleDetails(0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();

        // Deal funding
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).depositUnderlyingTokens(1.5e18);

        // Deal acceptance: 31 purchaseTokens in total between 3 wallets for a 3 purchaseTokens deal in total.
        // Deallocation could lead to precision errors
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 purchaseAmount1 = 1e18;
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1, 0);

        vm.stopPrank();
        vm.startPrank(user2);
        uint256 purchaseAmount2 = 10e18;
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2, 0);

        vm.stopPrank();
        vm.startPrank(user3);
        uint256 purchaseAmount3 = 20e18;
        deal(address(purchaseToken), user3, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount3, 0);

        //HolderClaim
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        vm.warp(AelinUpFrontDeal(upfrontDealAddress).purchaseExpiry() + 1 days);
        assertEq(purchaseToken.balanceOf(dealHolderAddress), 0);
        AelinUpFrontDeal(upfrontDealAddress).holderClaim();

        //Holder is likely to have accepted more than what the wallets will invest once the deallocation occurs
        assertEq(
            purchaseToken.balanceOf(dealHolderAddress),
            (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals
        );

        // PurchaserClaim 1
        vm.stopPrank();
        vm.startPrank(user1);

        uint256 adjustedShareAmountForUser = (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user1, 0) *
            underlyingDealTokenTotal) / AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) / BASE;

        uint256 purchasingRefund = AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user1, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user1, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user1), type(uint256).max - purchaseAmount1);
        vm.expectEmit(true, false, false, true);
        uint256 tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 0);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);

        // First purchaser gets refunded
        assertEq(purchaseToken.balanceOf(user1), type(uint256).max - purchaseAmount1 + purchasingRefund);

        // PurchaserClaim 2
        vm.stopPrank();
        vm.startPrank(user2);

        adjustedShareAmountForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user2, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user2, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user2, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user2), type(uint256).max - purchaseAmount2);
        vm.expectEmit(true, false, false, true);
        tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 1);
        emit ClaimDealTokens(user2, adjustedShareAmountForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);

        // Second purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(user2), type(uint256).max - purchaseAmount2 + purchasingRefund);

        // PurchaserClaim 3
        vm.stopPrank();
        vm.startPrank(user3);

        adjustedShareAmountForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user3, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user3, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user3, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3);

        // Due to precision error, there is not enough purchaseTokens in the contract to refund the last wallet
        // So the refund amount for the last wallet equals the contract's balance
        uint256 contractRemainingBalance = purchaseToken.balanceOf(upfrontDealAddress);
        assertGt(purchasingRefund, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 2);
        emit ClaimDealTokens(user3, adjustedShareAmountForUser, contractRemainingBalance);
        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);
        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3 + contractRemainingBalance);
    }

    function test_PrecisionError_HolderSide() public {
        // Deal config
        vm.startPrank(dealCreatorAddress);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinAllowList.InitData memory allowListInitEmpty;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 0,
            ipfsHash: "",
            merkleRoot: 0
        });

        IAelinUpFrontDeal.VestingSchedule[] memory vestingSchedules = new IAelinUpFrontDeal.VestingSchedule[](1);

        vestingSchedules[0].purchaseTokenPerDealToken = 2e18;
        vestingSchedules[0].vestingCliffPeriod = 1 days;
        vestingSchedules[0].vestingPeriod = 10 days;

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1.5e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 1 days,
            vestingSchedules: vestingSchedules,
            allowDeallocation: true
        });

        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(upfrontDealAddress).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(upfrontDealAddress).getVestingScheduleDetails(0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();

        // Deal funding
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).depositUnderlyingTokens(1.5e18);

        // Deal acceptance: 31 purchaseTokens in total between 3 wallets for a 3 purchaseTokens deal in total.
        // Deallocation could lead to precision errors
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 purchaseAmount1 = 1e18;
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1, 0);

        vm.stopPrank();
        vm.startPrank(user2);
        uint256 purchaseAmount2 = 10e18;
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2, 0);

        vm.stopPrank();
        vm.startPrank(user3);
        uint256 purchaseAmount3 = 20e18;
        deal(address(purchaseToken), user3, type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount3, 0);

        vm.warp(AelinUpFrontDeal(upfrontDealAddress).purchaseExpiry() + 1 days);

        // PurchaserClaim 1
        vm.stopPrank();
        vm.startPrank(user1);

        uint256 adjustedShareAmountForUser = (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user1, 0) *
            underlyingDealTokenTotal) / AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) / BASE;

        uint256 purchasingRefund = AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user1, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user1, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user1), type(uint256).max - purchaseAmount1);
        uint256 tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 0);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);

        // First purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(user1), type(uint256).max - purchaseAmount1 + purchasingRefund);

        // PurchaserClaim 2
        vm.stopPrank();
        vm.startPrank(user2);

        adjustedShareAmountForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user2, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user2, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user2, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user2), type(uint256).max - purchaseAmount2);
        tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 1);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user2, adjustedShareAmountForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);

        // Second purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(user2), type(uint256).max - purchaseAmount2 + purchasingRefund);

        // PurchaserClaim 3
        vm.stopPrank();
        vm.startPrank(user3);

        adjustedShareAmountForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).poolSharesPerUser(user3, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user3, 0) -
            ((AelinUpFrontDeal(upfrontDealAddress).purchaseTokensPerUser(user3, 0) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares());

        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3);
        tokenCount = AelinUpFrontDeal(upfrontDealAddress).tokenCount();
        assertEq(tokenCount, 2);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user3, adjustedShareAmountForUser, purchasingRefund);
        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim(0);
        assertEq(purchaseToken.balanceOf(user3), type(uint256).max - purchaseAmount3 + purchasingRefund);

        // Holder claim.
        // Since all the purchaser wallets have claimed, the holder
        // will claim the contract's balance instead of the intended raise amount
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        assertEq(purchaseToken.balanceOf(dealHolderAddress), 0);
        uint256 contractRemainingBalance = purchaseToken.balanceOf(upfrontDealAddress);
        uint256 intendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10 ** underlyingTokenDecimals;
        assertGt(intendedRaise, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            contractRemainingBalance,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(upfrontDealAddress).holderClaim();
        assertEq(purchaseToken.balanceOf(dealHolderAddress), contractRemainingBalance);
    }

    // /*//////////////////////////////////////////////////////////////
    //                  FUZZED Scenarios with precision error
    // //////////////////////////////////////////////////////////////*/

    function testFuzz_PrecisionError_PurchaserSide(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals,
        uint256 _purchaseAmount1,
        uint256 _purchaseAmount2,
        uint256 _purchaseAmount3
    ) public {
        _purchaseAmount1 = bound(_purchaseAmount1, 1, (1000000 * BASE) - 1);
        _purchaseAmount2 = bound(_purchaseAmount2, 1, (1000000 * BASE) - 1);
        _purchaseAmount3 = bound(_purchaseAmount3, 1, (1000000 * BASE) - 1);

        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        UpFrontDealVars memory dealVars = boundUpFrontDealVars(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _purchaseTokenDecimals,
            _underlyingTokenDecimals
        );

        FuzzedUpFrontDeal memory fuzzed = getFuzzedDeal(
            dealVars.sponsorFee,
            dealVars.underlyingDealTokenTotal,
            dealVars.purchaseTokenPerDealToken,
            dealVars.purchaseRaiseMinimum,
            dealVars.purchaseDuration,
            dealVars.vestingPeriod,
            dealVars.vestingCliffPeriod,
            dealVars.purchaseTokenDecimals,
            dealVars.underlyingTokenDecimals
        );

        vm.prank(dealCreatorAddress);
        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            fuzzed.dealData,
            fuzzed.dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        fuzzed.upFrontDeal = AelinUpFrontDeal(upfrontDealAddress);

        vm.startPrank(dealHolderAddress);
        deal(fuzzed.dealData.underlyingDealToken, dealHolderAddress, type(uint256).max);
        MockERC20(fuzzed.dealData.underlyingDealToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.depositUnderlyingTokens(dealVars.underlyingDealTokenTotal);
        vm.stopPrank();

        // Avoid "purchase amount too small"
        vm.assume(_purchaseAmount1 > dealVars.purchaseTokenPerDealToken / (10 ** dealVars.underlyingTokenDecimals));
        vm.assume(_purchaseAmount2 > dealVars.purchaseTokenPerDealToken / (10 ** dealVars.underlyingTokenDecimals));
        vm.assume(_purchaseAmount3 > dealVars.purchaseTokenPerDealToken / (10 ** dealVars.underlyingTokenDecimals));

        // Force deallocation
        vm.assume(
            _purchaseAmount1 + _purchaseAmount2 + _purchaseAmount3 >
                (dealVars.underlyingDealTokenTotal * dealVars.purchaseTokenPerDealToken) /
                    (10 ** dealVars.underlyingTokenDecimals)
        );

        vm.startPrank(user1);
        deal(address(fuzzed.dealData.purchaseToken), user1, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(fuzzed.dealData.purchaseToken), user2, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2, 0);
        vm.stopPrank();

        vm.startPrank(user3);
        deal(address(fuzzed.dealData.purchaseToken), user3, type(uint256).max);
        MockERC20(fuzzed.dealData.purchaseToken).approve(address(fuzzed.upFrontDeal), type(uint256).max);
        fuzzed.upFrontDeal.acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount3, 0);
        vm.stopPrank();

        //HolderClaim
        vm.startPrank(dealHolderAddress);
        vm.warp(fuzzed.upFrontDeal.purchaseExpiry() + 1);
        assertEq(MockERC20(fuzzed.dealData.purchaseToken).balanceOf(dealHolderAddress), 0);
        fuzzed.upFrontDeal.holderClaim();
        vm.stopPrank();

        // PurchaserClaim1
        vm.startPrank(user1);
        uint256 adjustedShareAmountForUser = (((fuzzed.upFrontDeal.poolSharesPerUser(user1, 0) *
            dealVars.underlyingDealTokenTotal) / fuzzed.upFrontDeal.totalPoolShares()) *
            (BASE - AELIN_FEE - dealVars.sponsorFee)) / BASE;

        uint256 purchasingRefund = fuzzed.upFrontDeal.purchaseTokensPerUser(user1, 0) -
            ((fuzzed.upFrontDeal.purchaseTokensPerUser(user1, 0) * dealVars.underlyingDealTokenTotal) /
                fuzzed.upFrontDeal.totalPoolShares());

        assertEq(MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user1), type(uint256).max - _purchaseAmount1);
        vm.expectEmit(true, false, false, true);
        assertEq(fuzzed.upFrontDeal.tokenCount(), 0);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser, purchasingRefund);
        fuzzed.upFrontDeal.purchaserClaim(0);

        assertEq(
            MockERC20(fuzzed.dealData.purchaseToken).balanceOf(dealHolderAddress),
            (dealVars.underlyingDealTokenTotal * dealVars.purchaseTokenPerDealToken) / 10 ** dealVars.underlyingTokenDecimals
        );

        // First purchaser gets refunded
        assertEq(
            MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user1),
            type(uint256).max - _purchaseAmount1 + purchasingRefund
        );
        vm.stopPrank();

        // PurchaserClaim 2
        vm.startPrank(user2);
        adjustedShareAmountForUser =
            (((fuzzed.upFrontDeal.poolSharesPerUser(user2, 0) * dealVars.underlyingDealTokenTotal) /
                fuzzed.upFrontDeal.totalPoolShares()) * (BASE - AELIN_FEE - dealVars.sponsorFee)) /
            BASE;

        purchasingRefund =
            fuzzed.upFrontDeal.purchaseTokensPerUser(user2, 0) -
            ((fuzzed.upFrontDeal.purchaseTokensPerUser(user2, 0) * dealVars.underlyingDealTokenTotal) /
                fuzzed.upFrontDeal.totalPoolShares());

        assertEq(MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user2), type(uint256).max - _purchaseAmount2);
        vm.expectEmit(true, false, false, true);
        assertEq(fuzzed.upFrontDeal.tokenCount(), 1);
        emit ClaimDealTokens(user2, adjustedShareAmountForUser, purchasingRefund);
        fuzzed.upFrontDeal.purchaserClaim(0);

        // Second purchaser refunded
        assertEq(
            MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user2),
            type(uint256).max - _purchaseAmount2 + purchasingRefund
        );
        vm.stopPrank();

        // PurchaserClaim 3
        vm.startPrank(user3);
        adjustedShareAmountForUser =
            (((fuzzed.upFrontDeal.poolSharesPerUser(user3, 0) * dealVars.underlyingDealTokenTotal) /
                fuzzed.upFrontDeal.totalPoolShares()) * (BASE - AELIN_FEE - dealVars.sponsorFee)) /
            BASE;
        purchasingRefund =
            fuzzed.upFrontDeal.purchaseTokensPerUser(user3, 0) -
            ((fuzzed.upFrontDeal.purchaseTokensPerUser(user3, 0) * dealVars.underlyingDealTokenTotal) /
                fuzzed.upFrontDeal.totalPoolShares());

        assertEq(MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user3), type(uint256).max - _purchaseAmount3);

        // Assert If remainingBalance < amount
        uint256 contractRemainingBalance = MockERC20(fuzzed.dealData.purchaseToken).balanceOf(upfrontDealAddress);
        if (purchasingRefund > contractRemainingBalance) {
            assertGt(purchasingRefund, contractRemainingBalance);
            vm.expectEmit(true, false, false, true);
            assertEq(fuzzed.upFrontDeal.tokenCount(), 2);
            emit ClaimDealTokens(user3, adjustedShareAmountForUser, contractRemainingBalance);
            assertEq(MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user3), type(uint256).max - _purchaseAmount3);
            fuzzed.upFrontDeal.purchaserClaim(0);
            assertEq(
                MockERC20(fuzzed.dealData.purchaseToken).balanceOf(user3),
                type(uint256).max - _purchaseAmount3 + contractRemainingBalance
            );
        }
    }

    // /*//////////////////////////////////////////////////////////////
    //                           largePool
    // //////////////////////////////////////////////////////////////*/

    function test_LargePool() public {
        // purchasing
        uint256 totalPurchaseAccepted;
        uint256 totalPoolShares;
        (uint256 underlyingDealTokenTotal, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (uint256 purchaseTokenPerDealToken, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(
            0
        );
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        vm.fee(1 gwei);
        for (uint256 i = 1; i < 10000; ++i) {
            uint256 _purchaseAmount = 1e34 + i;
            uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
            require(poolSharesAmount > 0, "purchase amount too small");
            vm.assume(poolSharesAmount > 0);
            if (i % 200 == 0) {
                vm.roll(block.number + 1);
            }
            AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
            address user = makeAddr(i);
            deal(address(purchaseToken), user, _purchaseAmount);
            vm.startPrank(user);
            purchaseToken.approve(address(dealAddressAllowDeallocation), _purchaseAmount);
            totalPurchaseAccepted += _purchaseAmount;
            totalPoolShares += poolSharesAmount;
            vm.expectEmit(true, false, false, true);
            emit AcceptDeal(user, 0, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
            AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount, 0);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), totalPoolShares);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user, 0), poolSharesAmount);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), totalPurchaseAccepted);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user, 0), _purchaseAmount);
            vm.stopPrank();
        }
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        for (uint256 i = 1; i < 10000; ++i) {
            if (i % 200 == 0) {
                vm.roll(block.number + 1);
            }
            address user = makeAddr(i);
            vm.startPrank(user);
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim(0);
            assertEq(MockERC721(dealAddressAllowDeallocation).balanceOf(user), 1, "vestingTokenBalance");
            assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(i - 1), user, "vestingTokenOwnerOf");
            vm.stopPrank();
        }
        vm.startPrank(dealHolderAddress);
        assertEq(purchaseToken.balanceOf(dealHolderAddress), 0);
        uint256 contractRemainingBalance = purchaseToken.balanceOf(dealAddressAllowDeallocation);
        uint256 intendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10 ** underlyingTokenDecimals;
        assertGt(intendedRaise, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            contractRemainingBalance,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        assertEq(purchaseToken.balanceOf(dealHolderAddress), contractRemainingBalance);
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
}
