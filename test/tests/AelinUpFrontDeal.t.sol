// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

contract AelinUpFrontDealTest is Test {
    function setUp() public {}

    /*//////////////////////////////////////////////////////////////
                            initialize()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertInitializeCannotCallInitializeTwice() public {}

    function testRevertInitializeCannotUseSameToken() public {}

    function testRevertInitializeCannotUseNullToken() public {}

    function testRevertInitializeCannotUseNullHolder() public {}

    function testRevertInitializeWrongDurations() public {}

    function testRevertInitializeWrongSponsorFee() public {}

    function testRevertInitializePurchaseTokenNotCompatible() public {}

    function testRevertInitializeWrongDealAmount() public {}

    function testRevertInitializeWrongRaiseAmount() public {}

    function testRevertInitializeCannotUseAllowListAndNFT() public {}

    function testRevertInitializeCannotUse721And1155() public {}

    function testRevertInitializeCannotUse1155And721() public {}

    function testRevertInitializeCannotUsePunksAnd1155() public {}

    function testRevertInitializeCannotUse1155AndPunks() public {}

    // Pass scenarios

    function testInitializeNoDeallocation() public {}

    function testInitializeAllowDeallocation() public {}

    function testInitializeOverFullDeposit() public {}

    function testInitializeAllowList() public {}

    function testInitializeNftGating721() public {}

    function testInitializeNftGatingMultiple721() public {}

    function testInitializeNftGatingPunks() public {}

    function testInitializeNftGating721AndPunks() public {}

    function testInitializeNftGating1155() public {}

    function testInitializeNftGatingMultiple1155() public {}

    /*//////////////////////////////////////////////////////////////
                        pre depositUnderlyingTokens()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertCannotAcceptDealBeforeDeposit(address _testAddress) public {}

    function testRevertPurchaserCannotClaimBeforeDeposit(address _testAddress) public {}

    function testRevertSponsorCannotClaimBeforeDeposit() public {}

    function testRevertHolderCannotClaimBeforeDeposit() public {}

    function testRevertTreasuryCannotClaimBeforeDeposit(address _testAddress) public {}

    function testRevertCannotClaimUnderlyingBeforeDeposit(address _testAddress, uint256 _tokenId) public {}

    // Pass scenarios

    function testClaimableBeforeDeposit(address _testAddress, uint256 _tokenId) public {}

    /*//////////////////////////////////////////////////////////////
                        depositUnderlyingTokens()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanDepositUnderlying(address _testAddress, uint256 _depositAmount) public {}

    function testRevertDepositUnderlyingNotEnoughBalance(uint256 _depositAmount, uint256 _holderBalance) public {}

    function testRevertDepositUnderlyingAfterComplete(uint256 _depositAmount) public {}

    // Pass scenarios

    function testPartialThenFullDepositUnderlying(uint256 _firstDepositAmount, uint256 _secondDepositAmount) public {}

    function testDepositUnderlyingFullDeposit(uint256 _depositAmount) public {}

    function testDirectUnderlyingDeposit() public {}

    /*//////////////////////////////////////////////////////////////
                        setHolder() / acceptHolder()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanSetNewHolder(address _futureHolder) public {}

    function testRevertOnlyDesignatedHolderCanAccept() public {}

    // Pass scenarios

    function testFuzzSetHolder(address _futureHolder) public {}

    function testFuzzAcceptHolder(address _futureHolder) public {}

    /*//////////////////////////////////////////////////////////////
                              vouch()
    //////////////////////////////////////////////////////////////*/

    function testFuzzVouchForDeal(address _attestant) public {
        vm.prank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Vouch(_attestant);
        AelinUpFrontDeal(dealAddress).vouch();
    }

    /*//////////////////////////////////////////////////////////////
                              disavow()
    //////////////////////////////////////////////////////////////*/

    function testFuzzDisavowForDeal(address _attestant) public {
        vm.prank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Disavow(_attestant);
        AelinUpFrontDeal(dealAddress).disavow();
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawExcess()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanCallWithdrawExcess(address _testAddress) public {}

    function testRevertNoExcessToWithdraw(uint256 _depositAmount) public {}

    // Pass scenarios

    function testWithdrawExcess(uint256 _depositAmount) public {}

    /*//////////////////////////////////////////////////////////////
                              acceptDeal()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertAcceptDealBeforeDepositComplete(address _user, uint256 _purchaseAmount) public {}

    function testRevertAcceptDealNotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {}

    function testRevertAcceptDealNotEnoughTokens() public {}

    function testRevertAcceptDealOverTotal() public {}

    function testRevertAcceptDealNotInAllowList(address _user, uint256 _purchaseAmount) public {}

    function testRevertAcceptDealOverAllowListAllocation(uint256 _purchaseAmount) public {}

    function testRevertAcceptDealNoNftList() public {}

    function testRevertAcceptDealNoNftPurchaseList() public {}

    function testRevertAcceptDealNftCollectionNotInTheList() public {}

    function testRevertAcceptDealERC720MustBeOwner() public {}

    function testRevertAcceptDealPunksMustBeOwner() public {}

    function testRevertAcceptDealERC721AlreadyUsed() public {}

    function testRevertAcceptDealERC721WalletAlreadyUsed() public {}

    function testRevertAcceptDealERC721OverAllowed() public {}

    function testRevertAcceptDealERC1155BalanceTooLow() public {}

    // Pass scenarios

    function testAcceptDealBasic(uint256 _purchaseAmount) public {}

    function testAcceptDealMultiplePurchasers() public {}

    function testAcceptDealAllowDeallocation() public {}

    function testAcceptDealAllowList(uint256 _purchaseAmount1, uint256 _purchaseAmount2, uint256 _purchaseAmount3) public {}

    function testAcceptDealERC721(uint256 _purchaseAmount) public {}

    function testAcceptDealPunks() public {}

    function testAcceptDealERC1155(uint256 _purchaseAmount) public {}

    /*//////////////////////////////////////////////////////////////
                            purchaserClaim()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertPurchaserClaimNotInWindow() public {}

    function testRevertPurchaserClaimNoShares(address _user) public {}

    // Pass scenarios

    // Does not meet purchaseRaiseMinimum
    function testPurchaserClaimRefund(uint256 _purchaseAmount) public {}

    function testPurchaserClaimNoDeallocation(uint256 _purchaseAmount) public {}

    function testPurchaserClaimWithDeallocation() public {}

    /*//////////////////////////////////////////////////////////////
                            sponsorClaim()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertSponsorClaimNotInWindow() public {}

    function testRevertSponsorClaimFailMinimumRaise(uint256 _purchaseAmount) public {}

    function testRevertSponsorClaimNotSponsor(uint256 _purchaseAmount, address _address) public {}

    function testRevertSponsorClaimAlreadyClaimed() public {}

    // Pass scenarios

    function testSponsorClaimNoDeallocation(uint256 _purchaseAmount) public {}

    function testSponsorClaimWithDeallocation() public {}

    /*//////////////////////////////////////////////////////////////
                            holderClaim()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertHolderClaimNotInWindow() public {}

    function testRevertHolderClaimNotHolder(address _address, uint256 _purchaseAmount) public {}

    function testRevertHolderClaimAlreadyClaimed() public {}

    function testRevertHolderClaimFailMinimumRaise(uint256 _purchaseAmount) public {}

    // Pass scenarios

    function testHolderClaimNoDeallocation() public {}

    function testHolderClaimWithDeallocation() public {}

    /*//////////////////////////////////////////////////////////////
                            feeEscrowClaim()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertEscrowClaimNotInWindow() public {}

    // Pass scenarios

    function testEscrowClaimNoDeallocation(address _address) public {}

    function testEscrowClaimWithDeallocation(address _address) public {}

    /*//////////////////////////////////////////////////////////////
                        claimableUnderlyingTokens()
    //////////////////////////////////////////////////////////////*/

    function testClaimableUnderlyingNotInWindow(uint256 _tokenId) public {}

    function testClaimableUnderlyingWithWrongTokenId(uint256 _purchaseAmount) public {}

    function testClaimableUnderlyingQuantityZero(address _address) public {}

    function testClaimableUnderlyingDuringVestingCliff(uint256 _timeAfterPurchasing) public {}

    function testClaimableUnderlyingAfterVestingEnd(uint256 _timeAfterPurchasing) public {}

    function testClaimableUnderlyingDuringVestingPeriod(uint256 _timeAfterPurchasing) public {}

    /*//////////////////////////////////////////////////////////////
                        claimUnderlying()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertClaimUnderlyingNotInWindow(uint256 _tokenId) public {}

    function testRevertClaimUnderlyingFailMinimumRaise(uint256 _purchaseAmount, uint256 _tokenId) public {}

    function testRevertClaimUnderlyingQuantityZero(address _address, uint256 _timeAfterPurchasing) public {}

    function testRevertClaimUnderlyingNotOwner(uint256 _purchaseAmount) public {}

    function testRevertClaimUnderlyingIncorrectTokenId(uint256 _purchaseAmount) public {}

    function testRevertClaimUnderlyingDuringVestingCliff(uint256 _timeAfterPurchasing) public {}

    // Pass scenarios

    function testClaimUnderlyingAfterVestingEnd(uint256 _timeAfterPurchasing) public {}

    function testClaimUnderlyingDuringVestingWindow(uint256 _timeAfterPurchasing) public {}

    /*//////////////////////////////////////////////////////////////
                        claimUnderlyingMutlipleEntries()
    //////////////////////////////////////////////////////////////*/

    function testClaimUnderlyingMultipleEntries() public {}

    /*//////////////////////////////////////////////////////////////
                        transfer()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function revertTransferNotOwner() public {}

    // Pass scenarios

    function testTransfer() public {}

    /*//////////////////////////////////////////////////////////////
                        transferVestingShare()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testTransferVestingShareWrongTokenId(uint256 _shareAmount) public {}

    function testTransferShareZero() public {}

    function testTransferShareTooHigh(uint256 _shareAmount) public {}

    // Pass scenarios

    function testTransferShare(uint256 _shareAmount) public {}

    // /*//////////////////////////////////////////////////////////////
    //                  Scenarios with precision error
    // //////////////////////////////////////////////////////////////*/

    function testScenarioWithPrecisionErrorPurchaserSide() public {}

    function testScenarioWithPrecisionErrorHolderSide() public {}

    // /*//////////////////////////////////////////////////////////////
    //                           largePool
    // //////////////////////////////////////////////////////////////*/

    function testTenThousandUserPool() public {}

    // /*//////////////////////////////////////////////////////////////
    //                           merkleTree
    // //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function tesReverttNoIpfsHashFailure() public {}

    function testRevertNoNftListFailure() public {}

    function testRevertNoAllowListFailure() public {}

    function testRevertPurchaseAmountTooHighFailure() public {}

    function testRevertInvalidProofFailure() public {}

    function testRevertNotMessageSenderFailure(address _investor) public {}

    function testRevertAlreadyPurchasedTokensFailure() public {}

    // Pass scenarios

    function testMerklePurchase() public {}
}
