// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";

contract AelinDealTest is Test, AelinTestUtils {
    AelinPoolFactory public poolFactory;
    AelinFeeEscrow public feeEscrow;

    address public poolAddress;
    address public poolOpenRedemptionDealAddress;
    address public poolNoOpenRedemptionDealAddress;
    address public dealAddress;
    address public dealOpenRedemptionAddress;
    address public dealNoOpenRedemptionAddress;

    function setUp() public {
        feeEscrow = new AelinFeeEscrow();
        poolFactory = new AelinPoolFactory(
            address(new AelinPool()),
            address(new AelinDeal()),
            aelinTreasury,
            address(feeEscrow)
        );

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        deal(address(purchaseToken), dealCreatorAddress, type(uint256).max);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);

        vm.startPrank(dealCreatorAddress);
        // pool creation
        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });
        poolAddress = poolFactory.createPool(poolData);
        poolOpenRedemptionDealAddress = poolFactory.createPool(poolData);
        poolNoOpenRedemptionDealAddress = poolFactory.createPool(poolData);

        // pool funding
        purchaseToken.approve(address(poolAddress), type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(1e27);
        purchaseToken.approve(address(poolOpenRedemptionDealAddress), type(uint256).max);
        AelinPool(poolOpenRedemptionDealAddress).purchasePoolTokens(1e27);
        purchaseToken.approve(address(poolNoOpenRedemptionDealAddress), type(uint256).max);
        AelinPool(poolNoOpenRedemptionDealAddress).purchasePoolTokens(1e35);

        vm.warp(block.timestamp + 20 days);

        dealAddress = AelinPool(poolAddress).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e25, // _purchaseTokenTotalForDeal
            1e35, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            10 days, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );

        dealOpenRedemptionAddress = AelinPool(poolOpenRedemptionDealAddress).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e25, // _purchaseTokenTotalForDeal
            1e35, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            10 days, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );

        dealNoOpenRedemptionAddress = AelinPool(poolNoOpenRedemptionDealAddress).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e35, // _purchaseTokenTotalForDeal
            1e35, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            0, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );

        vm.stopPrank();

        vm.startPrank(dealHolderAddress);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        underlyingDealToken.approve(address(dealOpenRedemptionAddress), type(uint256).max);
        AelinDeal(dealOpenRedemptionAddress).depositUnderlying(1e35);
        underlyingDealToken.approve(address(dealNoOpenRedemptionAddress), type(uint256).max);
        AelinDeal(dealNoOpenRedemptionAddress).depositUnderlying(1e35);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            initialize
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertWhen_InitMoreThanOnce() public {
        IAelinDeal.DealData memory dealData = IAelinDeal.DealData(
            address(underlyingDealToken), // _underlyingDealToken
            1e35, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            10 days, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            1e25, // _purchaseTokenTotalForDeal
            30 days // _holderFundingDuration
        );
        vm.expectRevert("can only initialize once");
        AelinDeal(dealAddress).initialize(
            string("poolName"),
            string("poolSymbol"),
            dealData,
            aelinTreasury,
            address(feeEscrow)
        );
    }

    function test_Initialize() public {
        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinDeal(dealAddress).name(), "aeDeal-POOL");
        assertEq(AelinDeal(dealAddress).symbol(), "aeD-POOL");
        assertEq(AelinDeal(dealAddress).holder(), dealHolderAddress);
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(underlyingDealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), 1e35);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e25);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), 20 days);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), 10 days);
        assertEq(proRataPeriod, 30 days);
        assertEq(openPeriod, 10 days);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinDeal(dealAddress).aelinTreasuryAddress(), address(aelinTreasury));
        assertEq(AelinDeal(dealAddress).aelinEscrowAddress(), address(feeEscrow));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (1e35 * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertEq(AelinDeal(dealAddress).tokenCount(), 0);
        assertTrue(!AelinDeal(dealAddress).depositComplete());

        assertTrue(AelinDeal(dealOpenRedemptionAddress).depositComplete());
    }

    /*//////////////////////////////////////////////////////////////
                            depositUnderlying
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositUnderlying_RevertWhen_PastDeadline(uint256 _depositAmount) public {
        vm.warp(AelinDeal(dealAddress).holderFundingExpiry());
        vm.expectRevert("deposit past deadline");
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
    }

    function test_DepositUnderlying_RevertWhen_DepositAlreadyComplete() public {
        uint256 depositAmount = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.startPrank(dealHolderAddress);
        AelinDeal(dealAddress).depositUnderlying(depositAmount);
        vm.expectRevert("deposit already complete");
        AelinDeal(dealAddress).depositUnderlying(depositAmount);
        vm.stopPrank();
    }

    function testFuzz_DepositUnderLying_SingleDepositToComplete(uint256 _depositAmount) public {
        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();
        vm.assume(_depositAmount < type(uint256).max);
        vm.assume(_depositAmount >= AelinDeal(dealAddress).underlyingDealTokenTotal());
        // anybody can call this function
        vm.startPrank(user1);
        deal(address(underlyingDealToken), user1, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit DepositDealToken(address(underlyingDealToken), user1, _depositAmount);
        vm.expectEmit(true, true, true, true);
        emit DealFullyFunded(
            poolAddress,
            block.timestamp,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod + openPeriod
        );
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        assertTrue(AelinDeal(dealAddress).depositComplete());
        vm.stopPrank();
    }

    function testFuzz_DepositUnderlying_MultipleDepositsToComplete(uint256 _depositAmount) public {
        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();
        uint256 underlyingDealTokenTotal = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.assume(_depositAmount < underlyingDealTokenTotal);
        vm.assume(_depositAmount * 2 >= underlyingDealTokenTotal);

        vm.startPrank(dealHolderAddress);
        // first deposit is made, but it is not enough
        vm.expectEmit(true, true, true, true);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _depositAmount);
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        assertFalse(AelinDeal(dealAddress).depositComplete());

        // second deposit is made
        vm.expectEmit(true, true, true, true);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _depositAmount);
        vm.expectEmit(true, true, true, true);
        emit DealFullyFunded(
            poolAddress,
            block.timestamp,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod + openPeriod
        );
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        assertTrue(AelinDeal(dealAddress).depositComplete());
        vm.stopPrank();
    }

    function test_DepositUnderlying_TransferToComplete() public {
        uint256 transferAmount = AelinDeal(dealAddress).underlyingDealTokenTotal();
        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, true);

        emit Transfer(dealHolderAddress, dealAddress, transferAmount);
        underlyingDealToken.transfer(dealAddress, transferAmount);
        assertFalse(AelinDeal(dealAddress).depositComplete());

        // we still have to call the depositUnderlying function to complete the deposit
        vm.expectEmit(true, true, true, true);
        emit DealFullyFunded(
            poolAddress,
            block.timestamp,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod,
            block.timestamp + proRataPeriod + openPeriod
        );
        AelinDeal(dealAddress).depositUnderlying(0);
        assertTrue(AelinDeal(dealAddress).depositComplete());

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            withdraw
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Withdraw_RevertWhen_NotHolder(address _user) public {
        vm.assume(_user != dealHolderAddress);
        vm.startPrank(_user);
        vm.expectRevert("only holder can access");
        AelinDeal(dealOpenRedemptionAddress).withdraw();
        vm.stopPrank();
    }

    function testFuzz_Withdraw_DepositOverTotal(uint256 _depositAmount) public {
        uint256 underlyingDealTokenTotal = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.assume(_depositAmount < 1e50);
        vm.assume(_depositAmount > underlyingDealTokenTotal);

        vm.startPrank(dealHolderAddress);
        uint256 holderBalanceBeforeWithdraw = underlyingDealToken.balanceOf(dealHolderAddress);
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);

        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount, "dealContractBalanceBefore");
        vm.expectEmit(true, true, false, true);
        emit Transfer(dealAddress, dealHolderAddress, _depositAmount - underlyingDealTokenTotal);
        AelinDeal(dealAddress).withdraw();

        assertEq(
            underlyingDealToken.balanceOf(dealHolderAddress),
            holderBalanceBeforeWithdraw - underlyingDealTokenTotal,
            "dealHolderBalanceAfter"
        );
        assertEq(underlyingDealToken.balanceOf(dealAddress), underlyingDealTokenTotal, "dealContractBalanceAfter");

        vm.stopPrank();
    }

    function testFuzz_Withdraw_DepositNotCompleted(uint256 _depositAmount) public {
        uint256 underlyingDealTokenTotal = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.assume(_depositAmount < underlyingDealTokenTotal);
        vm.assume(_depositAmount > 0);

        vm.startPrank(dealHolderAddress);
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        uint256 holderBalanceBeforeWithdraw = underlyingDealToken.balanceOf(dealHolderAddress);

        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount, "dealContractBalanceBefore");

        vm.expectRevert();
        AelinDeal(dealAddress).withdraw();

        vm.warp(AelinDeal(dealAddress).holderFundingExpiry());

        vm.expectEmit(true, true, false, true);
        emit Transfer(dealAddress, dealHolderAddress, _depositAmount);
        AelinDeal(dealAddress).withdraw();

        assertEq(
            underlyingDealToken.balanceOf(dealHolderAddress),
            holderBalanceBeforeWithdraw + _depositAmount,
            "dealHolderBalanceAfter"
        );
        assertEq(underlyingDealToken.balanceOf(dealAddress), 0, "dealContractBalanceAfter");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawExpiry
    //////////////////////////////////////////////////////////////*/

    function testFuzz_WithdrawExpiry_RevertWhen_NotHolder(address _user) public {
        vm.assume(_user != dealHolderAddress);
        vm.startPrank(_user);
        vm.expectRevert("only holder can access");
        AelinDeal(dealOpenRedemptionAddress).withdrawExpiry();
        vm.stopPrank();
    }

    function test_WithdrawExpiry_RevertWhen_BeforeRedemptionPeriod() public {
        vm.startPrank(dealHolderAddress);
        vm.expectRevert("redemption period not started");
        AelinDeal(dealAddress).withdrawExpiry();
        vm.stopPrank();
    }

    function test_WithdrawExpiry_RevertWhen_BeforeProRataRedemptionEnd() public {
        vm.startPrank(dealHolderAddress);
        vm.expectRevert("redeem window still active");
        AelinDeal(dealNoOpenRedemptionAddress).withdrawExpiry();
        vm.stopPrank();
    }

    function test_WithdrawExpiry_RevertWhen_BeforeOpenRedemptionEnd() public {
        vm.startPrank(dealHolderAddress);
        (, uint256 openRedemptionStart, ) = AelinDeal(dealOpenRedemptionAddress).openRedemption();
        vm.warp(openRedemptionStart);
        vm.expectRevert("redeem window still active");
        AelinDeal(dealOpenRedemptionAddress).withdrawExpiry();
        vm.stopPrank();
    }

    function testFuzz_WithdrawExpiry_NoOpenRedemption(uint256 _tokenAmount) public {
        (, , uint256 openRedemptionEnd) = AelinDeal(dealNoOpenRedemptionAddress).proRataRedemption();
        uint256 poolTokenBalance = AelinPool(poolNoOpenRedemptionDealAddress).balanceOf(dealCreatorAddress);
        vm.assume(_tokenAmount > 0);
        vm.assume(_tokenAmount < poolTokenBalance);
        uint256 sponsorFee = (_tokenAmount *
            10 ** (18 - AelinPool(poolNoOpenRedemptionDealAddress).purchaseTokenDecimals()) *
            AelinPool(poolNoOpenRedemptionDealAddress).sponsorFee()) / BASE;
        uint256 aelinFee = (_tokenAmount *
            10 ** (18 - AelinPool(poolNoOpenRedemptionDealAddress).purchaseTokenDecimals()) *
            AELIN_FEE) / BASE;

        vm.startPrank(dealCreatorAddress);
        // pool investor only accepts a part of the deal
        // to make sure holder can withdraw something
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(dealCreatorAddress, dealNoOpenRedemptionAddress, _tokenAmount, sponsorFee, aelinFee);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptDealTokens(_tokenAmount);
        vm.stopPrank();
        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);
        vm.startPrank(dealHolderAddress);
        uint256 withdrawAmount = underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress) -
            ((AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
                AelinDeal(dealNoOpenRedemptionAddress).totalUnderlyingAccepted()) / 1e18);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, withdrawAmount);
        AelinDeal(dealNoOpenRedemptionAddress).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance + withdrawAmount);
        vm.stopPrank();
    }

    function test_WithdrawExpiry_NoOpenRedemptionAcceptMax() public {
        (, , uint256 openRedemptionEnd) = AelinDeal(dealNoOpenRedemptionAddress).proRataRedemption();
        uint256 poolTokenBalance = AelinPool(poolNoOpenRedemptionDealAddress).balanceOf(dealCreatorAddress);
        uint256 sponsorFee = (poolTokenBalance *
            10 ** (18 - AelinPool(poolNoOpenRedemptionDealAddress).purchaseTokenDecimals()) *
            AelinPool(poolNoOpenRedemptionDealAddress).sponsorFee()) / BASE;
        uint256 aelinFee = (poolTokenBalance *
            10 ** (18 - AelinPool(poolNoOpenRedemptionDealAddress).purchaseTokenDecimals()) *
            AELIN_FEE) / BASE;

        vm.startPrank(dealCreatorAddress);
        // pool investor accepts max
        // so holder won't withdraw anything
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(dealCreatorAddress, dealNoOpenRedemptionAddress, poolTokenBalance, sponsorFee, aelinFee);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        vm.stopPrank();
        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);
        vm.startPrank(dealHolderAddress);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, 0);
        AelinDeal(dealNoOpenRedemptionAddress).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance);
        vm.stopPrank();
    }

    function test_WithdrawExpiry_WithOpenRedemptionPartialAccept() public {
        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;
        uint256 depositAmount = 1e25;

        // creation of a custom pool
        vm.startPrank(dealCreatorAddress);
        IAelinPool.PoolData memory poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });
        address poolAddress = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddress, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddress, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddress).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e25, // _purchaseTokenTotalForDeal
            1e25, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            10 days, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );
        vm.stopPrank();

        // holder funds the deal
        vm.startPrank(dealHolderAddress);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e25);
        vm.stopPrank();

        // we divide depositAmount / 2 because both investors deposited the same amount
        uint256 sponsorFee = ((depositAmount / 2) *
            10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) *
            AelinPool(poolAddress).sponsorFee()) / BASE;
        uint256 aelinFee = ((depositAmount / 2) * 10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) * AELIN_FEE) /
            BASE;

        // user 1 accepts max and user 2 doesn't accept anything
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddress, depositAmount / 2, sponsorFee, aelinFee);
        AelinPool(poolAddress).acceptMaxDealTokens();

        // we are now in the open redemption period
        (, uint256 openRedemptionStart, uint256 openRedemptionEnd) = AelinDeal(dealAddress).openRedemption();
        vm.warp(openRedemptionStart);

        // user 1 accepts a part of the openRedemption
        uint256 maxOpenAmount = AelinPool(poolAddress).purchaseTokenTotalForDeal() -
            AelinPool(poolAddress).totalAmountAccepted();
        uint openAmountAccepted = maxOpenAmount / 2;
        sponsorFee =
            (openAmountAccepted *
                10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) *
                AelinPool(poolAddress).sponsorFee()) /
            BASE;
        aelinFee = (openAmountAccepted * 10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) * AELIN_FEE) / BASE;

        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddress, openAmountAccepted, sponsorFee, aelinFee);
        AelinPool(poolAddress).acceptDealTokens(openAmountAccepted);
        vm.stopPrank();

        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);

        // holder can withdraw the rest
        vm.startPrank(dealHolderAddress);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 withdrawAmount = underlyingDealToken.balanceOf(dealAddress) -
            ((AelinDeal(dealAddress).underlyingPerDealExchangeRate() * AelinDeal(dealAddress).totalUnderlyingAccepted()) /
                1e18);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, withdrawAmount);
        AelinDeal(dealAddress).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance + withdrawAmount, "dealHolderBalance");
        vm.stopPrank();
    }

    function test_WithdrawExpiry_WithOpenRedemptionAcceptMax() public {
        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;
        uint256 depositAmount = 1e25;

        // creation of a custom pool
        vm.startPrank(dealCreatorAddress);
        IAelinPool.PoolData memory poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });
        address poolAddress = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddress, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddress, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddress).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e25, // _purchaseTokenTotalForDeal
            1e25, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            10 days, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );
        vm.stopPrank();

        // holder funds the deal
        vm.startPrank(dealHolderAddress);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e25);
        vm.stopPrank();

        // we divide depositAmount / 2 because both investors deposited the same amount
        uint256 sponsorFee = ((depositAmount / 2) *
            10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) *
            AelinPool(poolAddress).sponsorFee()) / BASE;
        uint256 aelinFee = ((depositAmount / 2) * 10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) * AELIN_FEE) /
            BASE;

        // user 1 accepts max and user 2 doesn't accept anything
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddress, depositAmount / 2, sponsorFee, aelinFee);
        AelinPool(poolAddress).acceptMaxDealTokens();

        // we are now in the open redemption period
        (, uint256 openRedemptionStart, uint256 openRedemptionEnd) = AelinDeal(dealAddress).openRedemption();
        vm.warp(openRedemptionStart);

        // user 1 accepts everything
        uint256 maxOpenAmount = AelinPool(poolAddress).purchaseTokenTotalForDeal() -
            AelinPool(poolAddress).totalAmountAccepted();
        sponsorFee =
            (maxOpenAmount *
                10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) *
                AelinPool(poolAddress).sponsorFee()) /
            BASE;
        aelinFee = (maxOpenAmount * 10 ** (18 - AelinPool(poolAddress).purchaseTokenDecimals()) * AELIN_FEE) / BASE;

        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddress, maxOpenAmount, sponsorFee, aelinFee);
        AelinPool(poolAddress).acceptMaxDealTokens();
        vm.stopPrank();

        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);

        // holder has nothing to withdraw
        vm.startPrank(dealHolderAddress);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 withdrawAmount = underlyingDealToken.balanceOf(dealAddress) -
            ((AelinDeal(dealAddress).underlyingPerDealExchangeRate() * AelinDeal(dealAddress).totalUnderlyingAccepted()) /
                1e18);
        assertEq(withdrawAmount, 0, "withdrawAmount");
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, 0);
        AelinDeal(dealAddress).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance, "dealHolderBalance");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            claimUnderlyingTokens
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            mintVestingToken
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            transferProtocolFee
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            transferProtocolFee
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            setHolder/acceptHolder
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            transfer
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            transferVestingShare
    //////////////////////////////////////////////////////////////*/

    event DealFullyFunded(
        address indexed poolAddress,
        uint256 proRataRedemptionStart,
        uint256 proRataRedemptionExpiry,
        uint256 openRedemptionStart,
        uint256 openRedemptionExpiry
    );

    event AcceptDeal(
        address indexed purchaser,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee
    );

    event WithdrawUnderlyingDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );

    event Transfer(address indexed from, address indexed to, uint256 value);
}
