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
import {IAelinVestingToken} from "contracts/interfaces/IAelinVestingToken.sol";

contract AelinDealTest is Test, AelinTestUtils, IAelinDeal, IAelinVestingToken {
    AelinPoolFactory public poolFactory;
    AelinFeeEscrow public feeEscrow;

    address public poolAddress;
    address public poolOpenRedemptionDealAddress;
    address public poolNoOpenRedemptionDealAddress;
    address public poolNoOpenRedemptionDealAddress_2;
    address public dealAddress;
    address public dealOpenRedemptionAddress;
    address public dealNoOpenRedemptionAddress;
    address public dealNoOpenRedemptionNoVestingPeriodAddress;

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
        poolNoOpenRedemptionDealAddress_2 = poolFactory.createPool(poolData);

        // pool funding
        purchaseToken.approve(address(poolAddress), type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(1e27);
        purchaseToken.approve(address(poolOpenRedemptionDealAddress), type(uint256).max);
        AelinPool(poolOpenRedemptionDealAddress).purchasePoolTokens(1e27);
        purchaseToken.approve(address(poolNoOpenRedemptionDealAddress), type(uint256).max);
        AelinPool(poolNoOpenRedemptionDealAddress).purchasePoolTokens(1e35);
        purchaseToken.approve(address(poolNoOpenRedemptionDealAddress_2), type(uint256).max);
        AelinPool(poolNoOpenRedemptionDealAddress_2).purchasePoolTokens(1e35);

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

        dealNoOpenRedemptionNoVestingPeriodAddress = AelinPool(poolNoOpenRedemptionDealAddress_2).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            1e35, // _purchaseTokenTotalForDeal
            1e35, // _underlyingDealTokenTotal
            0, // _vestingPeriod
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
        underlyingDealToken.approve(address(dealNoOpenRedemptionNoVestingPeriodAddress), type(uint256).max);
        AelinDeal(dealNoOpenRedemptionNoVestingPeriodAddress).depositUnderlying(1e35);

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
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e25 * 10 ** (18 - purchaseToken.decimals()));
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

    function testFuzz_Withdraw_OverTotalAfterDealAccepted(uint256 _depositAmount, uint256 _acceptAmount) public {
        uint256 underlyingDealTokenTotal = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.assume(_depositAmount < 1e50);
        vm.assume(_depositAmount > underlyingDealTokenTotal);

        vm.assume(_acceptAmount <= underlyingDealTokenTotal);
        vm.assume(_acceptAmount > 0);

        // holder funds the deal
        vm.startPrank(dealHolderAddress);
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        // contract balance equals the deposit
        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount);
        vm.stopPrank();

        // user accepts the deal
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolAddress).acceptMaxDealTokens();
        vm.stopPrank();

        // contract balance = deposit - protocolFee
        uint256 protocolFeePaid = (AelinDeal(dealAddress).totalProtocolFee() *
            AelinDeal(dealAddress).underlyingPerDealExchangeRate()) / 1e18;
        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount - protocolFeePaid);

        // holder withdraws the extra amount deposited
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, true);
        emit Transfer(dealAddress, dealHolderAddress, _depositAmount - underlyingDealTokenTotal);
        AelinDeal(dealAddress).withdraw();

        // contract balance = dealTokenTotal - protocolFeePaid
        assertEq(underlyingDealToken.balanceOf(dealAddress), underlyingDealTokenTotal - protocolFeePaid);
        vm.stopPrank();
    }

    function testFuzz_Withdraw_OverTotalAfterClaimed(uint256 _depositAmount, uint256 _acceptAmount) public {
        uint256 underlyingDealTokenTotal = AelinDeal(dealAddress).underlyingDealTokenTotal();
        vm.assume(_depositAmount < 1e50);
        vm.assume(_depositAmount > underlyingDealTokenTotal);

        vm.assume(_acceptAmount <= underlyingDealTokenTotal);
        vm.assume(_acceptAmount > 0);

        // holder funds the deal
        vm.startPrank(dealHolderAddress);
        AelinDeal(dealAddress).depositUnderlying(_depositAmount);
        // contract balance equals the deposit
        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount);
        vm.stopPrank();

        // user accepts the deal
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealAddress).ownerOf(0), dealCreatorAddress);

        // contract balance = deposit - protocolFee
        uint256 protocolFeePaid = (AelinDeal(dealAddress).totalProtocolFee() *
            AelinDeal(dealAddress).underlyingPerDealExchangeRate()) / 1e18;
        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount - protocolFeePaid);

        // we wait until the end of the vesting schedule
        vm.warp(AelinDeal(dealAddress).vestingExpiry() + 1 days);

        // user claims their underlying tokens
        (uint256 share, ) = AelinDeal(dealAddress).vestingDetails(0);
        uint amountClaimed = (share * AelinDeal(dealAddress).underlyingPerDealExchangeRate()) / 1e18;
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), amountClaimed);
        AelinDeal(dealAddress).claimUnderlyingTokens(0);

        // contract balance = deposit - protocolFee - underlyingClaimed
        assertEq(underlyingDealToken.balanceOf(dealAddress), _depositAmount - protocolFeePaid - amountClaimed);

        // sponsor claims their tokens
        AelinPool(poolAddress).sponsorClaim();
        assertEq(AelinDeal(dealAddress).ownerOf(1), dealCreatorAddress);
        (share, ) = AelinDeal(dealAddress).vestingDetails(1);
        uint sponsorAmountClaimed = (share * AelinDeal(dealAddress).underlyingPerDealExchangeRate()) / 1e18;
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 1, address(underlyingDealToken), sponsorAmountClaimed);
        AelinDeal(dealAddress).claimUnderlyingTokens(1);
        vm.stopPrank();

        // contract balance = deposit - protocolFee - underlyingClaimed - sponsorUnderlyingClaimed
        assertEq(
            underlyingDealToken.balanceOf(dealAddress),
            _depositAmount - protocolFeePaid - amountClaimed - sponsorAmountClaimed
        );

        // holder withdraws the extra amount deposited
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, true);
        emit Transfer(dealAddress, dealHolderAddress, _depositAmount - underlyingDealTokenTotal);
        AelinDeal(dealAddress).withdraw();
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
        uint256 withdrawAmount = AelinDeal(dealNoOpenRedemptionAddress).underlyingDealTokenTotal() -
            ((AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
                AelinDeal(dealNoOpenRedemptionAddress).totalDealTokenAccepted()) / 1e18);
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
        uint256 withdrawAmount = AelinDeal(dealNoOpenRedemptionAddress).underlyingDealTokenTotal() -
            ((AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
                AelinDeal(dealNoOpenRedemptionAddress).totalDealTokenAccepted()) / 1e18);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, withdrawAmount);
        AelinDeal(dealNoOpenRedemptionAddress).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance + withdrawAmount, "holderBalance");
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
        address poolAddr = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddr).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddr = AelinPool(poolAddr).createDeal(
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
        underlyingDealToken.approve(address(dealAddr), type(uint256).max);
        AelinDeal(dealAddr).depositUnderlying(1e25);
        vm.stopPrank();

        // we divide depositAmount / 2 because both investors deposited the same amount
        uint256 sponsorFee = ((depositAmount / 2) *
            10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) *
            AelinPool(poolAddr).sponsorFee()) / BASE;
        uint256 aelinFee = ((depositAmount / 2) * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) /
            BASE;

        // user 1 accepts max and user 2 doesn't accept anything
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, depositAmount / 2, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptMaxDealTokens();

        // we are now in the open redemption period
        (, uint256 openRedemptionStart, uint256 openRedemptionEnd) = AelinDeal(dealAddr).openRedemption();
        vm.warp(openRedemptionStart);

        // user 1 accepts a part of the openRedemption
        uint256 maxOpenAmount = AelinPool(poolAddr).purchaseTokenTotalForDeal() - AelinPool(poolAddr).totalAmountAccepted();
        uint openAmountAccepted = maxOpenAmount / 2;
        sponsorFee =
            (openAmountAccepted *
                10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) *
                AelinPool(poolAddr).sponsorFee()) /
            BASE;
        aelinFee = (openAmountAccepted * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) / BASE;

        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, openAmountAccepted, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptDealTokens(openAmountAccepted);
        vm.stopPrank();

        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);

        // holder can withdraw the rest
        vm.startPrank(dealHolderAddress);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 withdrawAmount = AelinDeal(dealAddr).underlyingDealTokenTotal() -
            ((AelinDeal(dealAddr).underlyingPerDealExchangeRate() * AelinDeal(dealAddr).totalDealTokenAccepted()) / 1e18);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, withdrawAmount);
        AelinDeal(dealAddr).withdrawExpiry();
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
        address poolAddr = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddr).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddr = AelinPool(poolAddr).createDeal(
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
        underlyingDealToken.approve(address(dealAddr), type(uint256).max);
        AelinDeal(dealAddr).depositUnderlying(1e25);
        vm.stopPrank();

        // we divide depositAmount / 2 because both investors deposited the same amount
        uint256 sponsorFee = ((depositAmount / 2) *
            10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) *
            AelinPool(poolAddr).sponsorFee()) / BASE;
        uint256 aelinFee = ((depositAmount / 2) * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) /
            BASE;

        // user 1 accepts max and user 2 doesn't accept anything
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, depositAmount / 2, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptMaxDealTokens();

        // we are now in the open redemption period
        (, uint256 openRedemptionStart, uint256 openRedemptionEnd) = AelinDeal(dealAddr).openRedemption();
        vm.warp(openRedemptionStart);

        // user 1 accepts everything
        uint256 maxOpenAmount = AelinPool(poolAddr).purchaseTokenTotalForDeal() - AelinPool(poolAddr).totalAmountAccepted();
        sponsorFee =
            (maxOpenAmount * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AelinPool(poolAddr).sponsorFee()) /
            BASE;
        aelinFee = (maxOpenAmount * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) / BASE;

        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, maxOpenAmount, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptMaxDealTokens();
        vm.stopPrank();

        // we are now at the end of the proRata period
        vm.warp(openRedemptionEnd + 1 days);

        // holder has nothing to withdraw
        vm.startPrank(dealHolderAddress);
        uint256 dealHolderBalance = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 withdrawAmount = AelinDeal(dealAddr).underlyingDealTokenTotal() -
            ((AelinDeal(dealAddr).underlyingPerDealExchangeRate() * AelinDeal(dealAddr).totalDealTokenAccepted()) / 1e18);
        // holder can withdraw the remaining underlying deal tokens
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(address(underlyingDealToken), dealHolderAddress, withdrawAmount);
        AelinDeal(dealAddr).withdrawExpiry();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), dealHolderBalance + withdrawAmount, "dealHolderBalance");
        vm.stopPrank();
    }

    function test_WithrawExpiry_AfterVestingClaims() public {
        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        uint256 purchaseTokenTotal = 100e18;
        uint256 purchaseAmount1 = 40e18;
        uint256 purchaseAmount2 = 60e18;

        // creation of a custom pool
        vm.startPrank(dealCreatorAddress);
        IAelinPool.PoolData memory poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 0,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });
        address poolAddr = poolFactory.createPool(poolData);
        vm.stopPrank();

        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(purchaseAmount1);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(purchaseAmount2);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddr).purchaseExpiry());

        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddr = AelinPool(poolAddr).createDeal(
            address(underlyingDealToken), // _underlyingDealToken
            purchaseTokenTotal, // _purchaseTokenTotalForDeal
            purchaseTokenTotal, // _underlyingDealTokenTotal
            10 days, // _vestingPeriod
            20 days, // _vestingCliffPeriod
            30 days, // _proRataRedemptionPeriod
            0, // _openRedemptionPeriod
            dealHolderAddress, // _holder
            30 days // _holderFundingDuration
        );
        vm.stopPrank();

        // holder funds the deal
        vm.startPrank(dealHolderAddress);
        underlyingDealToken.approve(address(dealAddr), type(uint256).max);
        AelinDeal(dealAddr).depositUnderlying(purchaseTokenTotal);
        vm.stopPrank();

        // user1 accepts max
        vm.startPrank(user1);
        uint256 sponsorFee = (purchaseAmount1 *
            10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) *
            AelinPool(poolAddr).sponsorFee()) / BASE;
        uint256 aelinFee = (purchaseAmount1 * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) / BASE;
        uint256 purchaseAmount1Fee = sponsorFee + aelinFee;
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, purchaseAmount1, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptMaxDealTokens();
        vm.stopPrank();

        // user2 accepts half of their allocation
        vm.startPrank(user2);
        sponsorFee =
            ((purchaseAmount2 / 2) *
                10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) *
                AelinPool(poolAddr).sponsorFee()) /
            BASE;
        aelinFee = ((purchaseAmount2 / 2) * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals()) * AELIN_FEE) / BASE;
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user2, dealAddr, purchaseAmount2 / 2, sponsorFee, aelinFee);
        AelinPool(poolAddr).acceptDealTokens(purchaseAmount2 / 2);
        vm.stopPrank();

        // we are now at the end of the proRata period
        (, , uint256 proRataRedemptionEnd) = AelinDeal(dealAddr).proRataRedemption();
        vm.warp(proRataRedemptionEnd + 1 days);

        // we are now at the end of the vesting schedule
        vm.warp(AelinDeal(dealAddr).vestingExpiry() + 1 days);

        // user1 claims all their deal tokens
        vm.startPrank(user1);
        assertEq(AelinDeal(dealAddr).ownerOf(0), user1);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(
            user1,
            0,
            address(underlyingDealToken),
            purchaseAmount1 - ((purchaseAmount1Fee * AelinDeal(dealAddr).underlyingPerDealExchangeRate()) / 1e18)
        );
        AelinDeal(dealAddr).claimUnderlyingTokens(0);
        vm.stopPrank();

        // holder withdraws the unsold tokens
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, true);
        emit WithdrawUnderlyingDealToken(
            address(underlyingDealToken),
            dealHolderAddress,
            purchaseTokenTotal - purchaseAmount1 - (purchaseAmount2 - (purchaseAmount2 / 2))
        );
        AelinDeal(dealAddr).withdrawExpiry();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            claimUnderlyingTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimUnderlyingTokens_RevertWhen_NotOwner(address _user) public {
        vm.assume(_user != dealCreatorAddress);
        vm.assume(_user != address(0));
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        vm.stopPrank();
        vm.startPrank(_user);
        vm.expectRevert("must be owner to claim");
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        vm.stopPrank();
    }

    function test_ClaimUnderlyingTokens_NothingToClaimBeforeVestingStarts() public {
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0), 0);
        vm.stopPrank();
    }

    function test_ClaimUnderlyingTokens_NothingToClaimAfterClaimingAll() public {
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        // we are now after the end of the vesting period
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry() + 1 days);
        // claiming everything first
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        // claiming again after a day should revert
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry() + 2 days);
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0), 0);
        vm.stopPrank();
    }

    function testFuzz_ClaimUnderlyingTokens_RevertWhen_WrongTokenId(address _user) public {
        vm.assume(_user != dealCreatorAddress);
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        vm.expectRevert("ERC721: invalid token ID");
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        vm.stopPrank();
    }

    function test_ClaimUnderlyingTokens_BeforeVestingEnd() public {
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        // we assume user is the first claimer so owns deal token ID = 0;
        uint256 vestingExpiry = AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry();
        uint256 vestingPeriod = AelinDeal(dealNoOpenRedemptionAddress).vestingPeriod();
        (uint256 share, uint256 lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(lastClaimedAt, AelinDeal(dealNoOpenRedemptionAddress).vestingCliffExpiry());
        // user can claim a part of their deal tokens
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingCliffExpiry() + 1 days);
        uint256 maxTime = block.timestamp;
        uint256 minTime = lastClaimedAt;
        uint256 claimableAmount = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
            ((share * (maxTime - minTime)) / vestingPeriod)) / 1e18;

        uint256 contractBalanceBeforeClaim = underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress);
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), 0, "initialUserDealTokenBalance");
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);

        // post claim checks
        (, lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(lastClaimedAt, block.timestamp, "lastClaimedAt");
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), claimableAmount, "userDealTokenBalance");
        assertEq(
            underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress),
            contractBalanceBeforeClaim - claimableAmount,
            "contractBalancePostClaim"
        );

        // we wait another day and claim
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingCliffExpiry() + 2 days);
        maxTime = block.timestamp;
        minTime = lastClaimedAt;
        claimableAmount =
            (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
                ((share * (maxTime - minTime)) / vestingPeriod)) /
            1e18;
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);

        // post claim checks
        (, lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(lastClaimedAt, block.timestamp, "lastClaimedAt");
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), 2 * claimableAmount, "userDealTokenBalance");
        assertEq(
            underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress),
            contractBalanceBeforeClaim - 2 * claimableAmount,
            "contractBalancePostClaim"
        );
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);

        // we wait until vesting period expires and claim
        vm.warp(vestingExpiry + 2 days);
        claimableAmount =
            ((AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() * share) / 1e18) -
            (2 * claimableAmount);
        vm.expectEmit(true, false, false, false);
        emit VestingTokenBurned(0);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        uint256 totalShareInUnderlying = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() * share) /
            1e18;
        // post claim checks
        (, lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(lastClaimedAt, 0, "lastClaimedAt");
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), totalShareInUnderlying, "userDealTokenBalance");
        assertEq(
            underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress),
            contractBalanceBeforeClaim - totalShareInUnderlying,
            "contractBalancePostClaim"
        );
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);

        // we wait another day and check that user doesn't have tokens to claim
        vm.warp(vestingExpiry + 3 days);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimableUnderlyingTokens(0), 0);

        vm.stopPrank();
    }

    function test_ClaimUnderlyingTokens_AfterVestingEnd() public {
        vm.startPrank(dealCreatorAddress);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        // we assume user is the first claimer so owns deal token ID = 0;
        uint256 vestingExpiry = AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry();
        (uint256 share, uint256 lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(lastClaimedAt, AelinDeal(dealNoOpenRedemptionAddress).vestingCliffExpiry());

        // we wait until vesting period ends
        vm.warp(vestingExpiry + 1 days);

        uint256 contractBalanceBeforeClaim = underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress);
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), 0, "initialUserDealTokenBalance");
        uint256 claimableAmount = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() * share) / 1e18;
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        vm.expectEmit(true, false, false, false);
        emit VestingTokenBurned(0);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);

        // post claim checks
        (, lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(lastClaimedAt, 0, "lastClaimedAt");
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), claimableAmount, "userDealTokenBalance");
        assertEq(
            underlyingDealToken.balanceOf(dealNoOpenRedemptionAddress),
            contractBalanceBeforeClaim - claimableAmount,
            "contractBalancePostClaim"
        );

        // we wait another day and check that user doesn't have tokens to claim
        vm.warp(vestingExpiry + 3 days);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimableUnderlyingTokens(0), 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            claimableUnderlyingTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimableUnderlyingTokens() public {
        AelinPool pool = AelinPool(poolNoOpenRedemptionDealAddress);
        AelinDeal deal = AelinDeal(dealNoOpenRedemptionAddress);

        // lastClaimedAt is 0
        (uint256 share, uint256 lastClaimedAt) = deal.vestingDetails(0);
        assertEq(lastClaimedAt, 0);
        assertEq(deal.claimableUnderlyingTokens(0), 0);

        // lastClaimedAt > 0
        vm.startPrank(dealCreatorAddress);
        pool.acceptMaxDealTokens();
        vm.stopPrank();
        (share, lastClaimedAt) = deal.vestingDetails(0);

        // Before vesting Cliff expiry
        assertGt(lastClaimedAt, 0);
        assertEq(deal.claimableUnderlyingTokens(0), 0);

        // After vesting Cliff expiry
        vm.warp(deal.vestingCliffExpiry() + 1 days);
        uint256 maxTime = block.timestamp;
        uint256 minTime = deal.vestingCliffExpiry();
        uint256 claimableAmount = (deal.underlyingPerDealExchangeRate() *
            ((share * (maxTime - minTime)) / deal.vestingPeriod())) / 1e18;

        assertEq(deal.claimableUnderlyingTokens(0), claimableAmount);

        // After vesting expiry
        vm.warp(deal.vestingCliffExpiry() + deal.vestingPeriod() + 1 days);
        (share, lastClaimedAt) = deal.vestingDetails(0);
        maxTime = deal.vestingExpiry();
        minTime = lastClaimedAt;
        claimableAmount =
            (deal.underlyingPerDealExchangeRate() * ((share * (maxTime - minTime)) / deal.vestingPeriod())) /
            1e18;

        assertEq(deal.claimableUnderlyingTokens(0), claimableAmount);
    }

    function testFuzz_ClaimableUnderlyingTokens_NoVestingPeriod() public {
        AelinPool pool = AelinPool(poolNoOpenRedemptionDealAddress_2);
        AelinDeal deal = AelinDeal(dealNoOpenRedemptionNoVestingPeriodAddress);

        // lastClaimedAt is 0
        (uint256 share, uint256 lastClaimedAt) = deal.vestingDetails(0);
        assertEq(lastClaimedAt, 0);
        assertEq(deal.claimableUnderlyingTokens(0), 0);

        // lastClaimedAt > 0
        vm.startPrank(dealCreatorAddress);
        pool.acceptMaxDealTokens();
        (share, lastClaimedAt) = deal.vestingDetails(0);

        // Before vesting Cliff expiry
        assertGt(lastClaimedAt, 0);
        assertEq(deal.claimableUnderlyingTokens(0), 0);

        // After vesting Cliff expiry
        vm.warp(deal.vestingCliffExpiry());
        uint256 claimableAmount = (deal.underlyingPerDealExchangeRate() * share) / 1e18;
        assertEq(deal.claimableUnderlyingTokens(0), claimableAmount);
        assertEq(deal.balanceOf(dealCreatorAddress), 1);
        vm.expectEmit(true, false, false, false);
        emit VestingTokenBurned(0);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        deal.claimUnderlyingTokens(0);

        // Token is burned and user can't claim more after
        vm.warp(deal.vestingCliffExpiry() + 1 days);
        assertEq(deal.balanceOf(dealCreatorAddress), 0);
        assertEq(deal.claimableUnderlyingTokens(0), 0);
        vm.expectRevert("ERC721: invalid token ID");
        deal.claimUnderlyingTokens(0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                claimUnderlyingMultipleEntries()
    //////////////////////////////////////////////////////////////*/

    function test_ClaimUnderlyingMultipleEntries() public {
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
        address poolAddr = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddr).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddr = AelinPool(poolAddr).createDeal(
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
        underlyingDealToken.approve(address(dealAddr), type(uint256).max);
        AelinDeal(dealAddr).depositUnderlying(1e25);
        vm.stopPrank();

        // user 1 accepts the deal
        vm.startPrank(user1);
        AelinPool(poolAddr).acceptMaxDealTokens();
        vm.stopPrank();

        // user 2 accepts the deal
        vm.startPrank(user2);
        AelinPool(poolAddr).acceptMaxDealTokens();

        // user 1 and user 2 both hold vesting token NFTs
        assertEq(AelinDeal(dealAddr).ownerOf(0), user1);
        assertEq(AelinDeal(dealAddr).balanceOf(user1), 1);
        assertEq(AelinDeal(dealAddr).ownerOf(1), user2);
        assertEq(AelinDeal(dealAddr).balanceOf(user2), 1);

        // user 2 transfers their vesting token NFT to user 1
        AelinDeal(dealAddr).transfer(user1, 1, "0x0");
        assertEq(AelinDeal(dealAddr).ownerOf(0), user1);
        assertEq(AelinDeal(dealAddr).ownerOf(1), user1);
        assertEq(AelinDeal(dealAddr).balanceOf(user1), 2);
        assertEq(AelinDeal(dealAddr).balanceOf(user2), 0);
        vm.stopPrank();

        // we wait until we reach the end of the vesting schedule
        vm.warp(AelinDeal(dealAddr).vestingExpiry() + 1 days);

        // user 1 vests the tokens from both NFTs
        vm.startPrank(user1);
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        vm.expectEmit(true, true, false, true);
        (uint256 share1, ) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        (uint256 share2, ) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        emit ClaimedUnderlyingDealToken(user1, 0, address(underlyingDealToken), share1);
        emit ClaimedUnderlyingDealToken(user1, 0, address(underlyingDealToken), share2);
        AelinDeal(dealAddr).claimUnderlyingMultipleEntries(indices);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            mintVestingToken
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MintVestingToken_RevertWhen_DepositNotCompleted(
        address _minter,
        uint256 _shareAmount,
        uint256 _fee
    ) public {
        vm.startPrank(user1);
        vm.expectRevert("deposit not complete");
        AelinDeal(dealAddress).createVestingSchedule(_minter, _shareAmount, _fee, _fee);
        vm.stopPrank();
    }

    function testFuzz_MintVestingToken_RevertWhen_NotPool(address _minter, uint256 _shareAmount, uint256 _fee) public {
        vm.startPrank(user1);
        vm.expectRevert("only AelinPool can access");
        AelinDeal(dealNoOpenRedemptionAddress).createVestingSchedule(_minter, _shareAmount, _fee, _fee);
        vm.stopPrank();
    }

    function test_MintVestingToken() public {
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
        address poolAddr = poolFactory.createPool(poolData);
        vm.stopPrank();
        // user 1 invests in the pool
        vm.startPrank(user1);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user1, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // user 2 invests in the pool
        vm.startPrank(user2);
        purchaseToken.approve(poolAddr, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        AelinPool(poolAddr).purchasePoolTokens(depositAmount);
        vm.stopPrank();

        // purchase window is now expired
        vm.warp(AelinPool(poolAddr).purchaseExpiry());
        // creation of deal
        vm.startPrank(dealCreatorAddress);
        address dealAddr = AelinPool(poolAddr).createDeal(
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
        underlyingDealToken.approve(address(dealAddr), type(uint256).max);
        AelinDeal(dealAddr).depositUnderlying(1e25);
        vm.stopPrank();

        // we divide depositAmount / 2 because both investors deposited the same amount
        uint256 depositAmountFormatted = (depositAmount / 2) * 10 ** (18 - AelinPool(poolAddr).purchaseTokenDecimals());
        uint256 sponsorFee = (depositAmountFormatted * AelinPool(poolAddr).sponsorFee()) / BASE;
        uint256 aelinFee = (depositAmountFormatted * AELIN_FEE) / BASE;
        uint256 computedShareAmount = depositAmountFormatted - sponsorFee - aelinFee;

        // user 1 accepts max
        vm.startPrank(user1);
        assertEq(AelinDeal(dealAddr).tokenCount(), 0);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user1, dealAddr, depositAmount / 2, sponsorFee, aelinFee);
        emit VestingTokenMinted(user1, 0, computedShareAmount, AelinDeal(dealAddr).vestingCliffExpiry());
        AelinPool(poolAddr).acceptMaxDealTokens();

        // user1 now owns  a vesting token
        assertEq(AelinDeal(dealAddr).tokenCount(), 1, "tokenCount");
        assertEq(AelinDeal(dealAddr).ownerOf(0), user1, "ownerOf");
        assertEq(AelinDeal(dealAddr).balanceOf(user1), 1);
        (uint256 share, uint256 lastClaimedAt) = AelinDeal(dealAddr).vestingDetails(0);
        assertEq(share, computedShareAmount, "shareAmount");
        assertEq(lastClaimedAt, AelinDeal(dealAddr).vestingCliffExpiry());

        vm.stopPrank();

        // user 2 accepts max
        vm.startPrank(user2);
        vm.expectEmit(true, true, false, true);
        emit AcceptDeal(user2, dealAddr, depositAmount / 2, sponsorFee, aelinFee);
        emit VestingTokenMinted(user2, 1, computedShareAmount, AelinDeal(dealAddr).vestingCliffExpiry());
        AelinPool(poolAddr).acceptMaxDealTokens();

        // user2 now owns  a vesting token
        assertEq(AelinDeal(dealAddr).tokenCount(), 2, "tokenCount");
        assertEq(AelinDeal(dealAddr).ownerOf(1), user2, "ownerOf");
        assertEq(AelinDeal(dealAddr).balanceOf(user2), 1);
        (share, lastClaimedAt) = AelinDeal(dealAddr).vestingDetails(1);
        assertEq(share, computedShareAmount, "shareAmount");
        assertEq(lastClaimedAt, AelinDeal(dealAddr).vestingCliffExpiry());

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            transferProtocolFee
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TransferProtocolFee_RevertWhen_DepositNotCompleted(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("deposit not complete");
        AelinDeal(dealAddress).transferProtocolFee(0);
        vm.stopPrank();
    }

    function test_TransferProtocolFee_RevertWhen_NotPool(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("only AelinPool can access");
        AelinDeal(dealOpenRedemptionAddress).transferProtocolFee(0);
        vm.stopPrank();
    }

    function testFuzz_TransferProtocolFee(uint256 _poolTokenAmount) public {
        vm.assume(_poolTokenAmount <= AelinPool(poolNoOpenRedemptionDealAddress).balanceOf(dealCreatorAddress));
        vm.assume(_poolTokenAmount > 0);

        address feeEscrowAddress = address(AelinDeal(dealNoOpenRedemptionAddress).aelinFeeEscrow());
        uint256 depositAmountFormatted = (_poolTokenAmount) *
            10 ** (18 - AelinPool(poolNoOpenRedemptionDealAddress).purchaseTokenDecimals());
        uint256 aelinFee = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
            ((depositAmountFormatted * AELIN_FEE) / BASE)) / 1e18;

        vm.startPrank(dealCreatorAddress);
        vm.expectEmit(true, true, false, true);
        emit Transfer(dealNoOpenRedemptionAddress, feeEscrowAddress, aelinFee);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptDealTokens(_poolTokenAmount);
        assertEq(underlyingDealToken.balanceOf(feeEscrowAddress), aelinFee, "escrowBalance");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            setHolder/acceptHolder
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SetHolder_RevertWhen_NotHolder(address _user) public {
        vm.assume(_user != dealHolderAddress);
        vm.startPrank(_user);
        vm.expectRevert("only holder can access");
        AelinDeal(dealAddress).setHolder(address(0));
        vm.stopPrank();
    }

    function test_SetHolder_RevertWhen_HolderIsZero() public {
        vm.startPrank(dealHolderAddress);
        vm.expectRevert("holder cant be null");
        AelinDeal(dealAddress).setHolder(address(0));
        vm.stopPrank();
    }

    function test_SetHolder(address _futureHolder) public {
        vm.assume(_futureHolder != address(0));
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, false, false, false);
        emit HolderSet(_futureHolder);
        AelinDeal(dealAddress).setHolder(_futureHolder);
        assertEq(AelinDeal(dealAddress).futureHolder(), _futureHolder);
        vm.stopPrank();
    }

    function testFuzz_AcceptHolder_RevertWhen_NotFutureHolder(address _futureHolder, address _user) public {
        vm.assume(_futureHolder != address(0));
        vm.assume(_futureHolder != _user);
        vm.startPrank(dealHolderAddress);
        AelinDeal(dealAddress).setHolder(_futureHolder);
        vm.stopPrank();
        vm.startPrank(_user);
        vm.expectRevert("only future holder can access");
        AelinDeal(dealAddress).acceptHolder();
        vm.stopPrank();
    }

    function testFuzz_AcceptHolder(address _futureHolder) public {
        vm.assume(_futureHolder != address(0));
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, false, false, false);
        emit HolderSet(_futureHolder);
        AelinDeal(dealAddress).setHolder(_futureHolder);
        vm.stopPrank();
        vm.startPrank(_futureHolder);
        vm.expectEmit(true, false, false, false);
        emit HolderAccepted(_futureHolder);
        AelinDeal(dealAddress).acceptHolder();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            transfer
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_RevertWhen_NotOwner() public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);
        vm.stopPrank();

        // another user tries to transfer this exact
        vm.startPrank(user1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user1), 0);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        AelinDeal(dealNoOpenRedemptionAddress).transfer(user2, 0, "0x0");
        vm.stopPrank();
    }

    function testFuzz_Transfer_RevertWhen_WrongTokenId() public {
        // token ID = 0 hasn't been minted yet
        vm.startPrank(user1);
        vm.expectRevert("ERC721: invalid token ID");
        AelinDeal(dealNoOpenRedemptionAddress).transfer(user2, 0, "0x0");
        vm.stopPrank();
    }

    function test_Transfer() public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);
        (uint256 shareInitial, uint256 lastClaimedAtInitial) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);

        // dealCreator user transfers their token to user1
        AelinDeal(dealNoOpenRedemptionAddress).transfer(user1, 0, "0x0");
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user1), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), user1);
        vm.stopPrank();

        // user1 transfers their token to user2
        vm.startPrank(user1);
        AelinDeal(dealNoOpenRedemptionAddress).transfer(user2, 0, "0x0");
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user1), 0);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user2), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), user2);
        (uint256 share, uint256 lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        uint256 claimableAmount = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() * share) / 1e18;

        // we check that vesting schedule is identical
        assertEq(share, shareInitial);
        assertEq(lastClaimedAt, lastClaimedAtInitial);

        // nobody except user2 can claim
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry() + 1 days);
        vm.stopPrank();
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("must be owner to claim");
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert("must be owner to claim");
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        vm.stopPrank();
        vm.startPrank(user2);
        assertEq(underlyingDealToken.balanceOf(user2), 0);
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(user2, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        assertEq(underlyingDealToken.balanceOf(user2), claimableAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            transferVestingShare
    //////////////////////////////////////////////////////////////*/

    function test_TransferVestingShare_RevertWhen_NotOwner() public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);

        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert("must be owner to transfer");
        AelinDeal(dealNoOpenRedemptionAddress).transferVestingShare(user2, 0, 1);
        vm.stopPrank();
    }

    function test_TransferVestingShare_RevertWhen_WrongTokenId() public {
        vm.startPrank(user1);
        vm.expectRevert("ERC721: invalid token ID");
        AelinDeal(dealNoOpenRedemptionAddress).transferVestingShare(user2, 0, 1);
        vm.stopPrank();
    }

    function test_TransferVestingShare_RevertWhen_ShareAmountIsZero() public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);

        vm.expectRevert("share amount should be > 0");
        AelinDeal(dealNoOpenRedemptionAddress).transferVestingShare(user2, 0, 0);
        vm.stopPrank();
    }

    function test_TransferVestingShare_RevertWhen_ShareAmountTooHigh() public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);

        (uint256 share, ) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        // dealCreator user sends more than their share
        vm.expectRevert("cant transfer more than current share");
        AelinDeal(dealNoOpenRedemptionAddress).transferVestingShare(user2, 0, share + 1);
        vm.stopPrank();
    }

    function testFuzz_TransferVestingShare(uint256 _shareAmount) public {
        // dealCreator user accepts the deal and mint their vesting token
        vm.startPrank(dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 0);
        AelinPool(poolNoOpenRedemptionDealAddress).acceptMaxDealTokens();
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);

        (uint256 share, uint256 lastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        vm.assume(_shareAmount > 1e18);
        vm.assume(_shareAmount < share);

        // dealCreator user transfers a part of their share to user1
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user1), 0);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(user1, 1, _shareAmount, lastClaimedAt);
        vm.expectEmit(true, true, true, true);
        emit VestingShareTransferred(dealCreatorAddress, user1, 0, _shareAmount);
        AelinDeal(dealNoOpenRedemptionAddress).transferVestingShare(user1, 0, _shareAmount);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(dealCreatorAddress), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).balanceOf(user1), 1);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(0), dealCreatorAddress);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).ownerOf(1), user1);

        // dealCreator has their share reduced
        (uint256 newShare, uint256 newLastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(0);
        assertEq(newShare, share - _shareAmount);
        assertEq(newLastClaimedAt, lastClaimedAt);

        // user1 now has their share
        (newShare, newLastClaimedAt) = AelinDeal(dealNoOpenRedemptionAddress).vestingDetails(1);
        assertEq(newShare, _shareAmount);
        assertEq(newLastClaimedAt, lastClaimedAt);

        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry() + 1 days);
        uint256 claimableAmount = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() *
            (share - _shareAmount)) / 1e18;

        // dealCreator user can claim their share
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(dealCreatorAddress, 0, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(0);
        assertEq(underlyingDealToken.balanceOf(dealCreatorAddress), claimableAmount);
        vm.stopPrank();

        // user1 can claim their share
        vm.startPrank(user1);
        claimableAmount = (AelinDeal(dealNoOpenRedemptionAddress).underlyingPerDealExchangeRate() * (_shareAmount)) / 1e18;
        vm.expectEmit(true, true, false, true);
        emit ClaimedUnderlyingDealToken(user1, 1, address(underlyingDealToken), claimableAmount);
        AelinDeal(dealNoOpenRedemptionAddress).claimUnderlyingTokens(1);
        assertEq(underlyingDealToken.balanceOf(user1), claimableAmount);

        // we make sure that nobody can claim after this
        vm.warp(AelinDeal(dealNoOpenRedemptionAddress).vestingExpiry() + 10 days);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimableUnderlyingTokens(0), 0);
        assertEq(AelinDeal(dealNoOpenRedemptionAddress).claimableUnderlyingTokens(1), 0);

        vm.stopPrank();
    }

    event AcceptDeal(
        address indexed purchaser,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee
    );

    event Transfer(address indexed from, address indexed to, uint256 value);
}
