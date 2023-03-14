// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.6;

// import "forge-std/Test.sol";

// contract AelinPoolTest is Test, AelinTestUtils {
//     function setUp() public {}

//     /*//////////////////////////////////////////////////////////////
//                             initialize
//     //////////////////////////////////////////////////////////////*/

//     function test_Initialize_RevertWhen_InitiatedTwice() public {}

//     function test_Initialize_RevertWhen_WrongPurchaseDuration() public {}

//     function test_Initialize_RevertWhen_WrongPoolDuration() public {}

//     function test_Initialize_RevertWhen_WrongSponsorFee() public {}

//     function test_Initialize_RevertWhen_TooManyDecimals() public {}

//     function test_Initialize_RevertWhen_AllowListIncorrect() public {}

//     function test_Initialize_RevertWhen_NotOnlyERC721() public {}

//     function test_Initialize_RevertWhen_NotOnlyERC1155() public {}

//     function test_Initialize_RevertWhen_CollectionIncompatible() public {}

//     function test_Initialize_Pool() public {}

//     function test_Initialize_PoolERC721() public {}

//     function test_Initialize_PoolPunks() public {}

//     function test_Initialize_PoolERC721AndPunks() public {}

//     function test_Initialize_PoolERC1155() public {}

//     /*//////////////////////////////////////////////////////////////
//                             purchasePoolTokens
//     //////////////////////////////////////////////////////////////*/

//     function test_PurchasePoolTokens_RevertWhen_NotInPurchaseWindow() public {}

//     function test_PurchasePoolTokens_RevertWhen_HasNftList() public {}

//     function test_PurchasePoolTokens_RevertWhen_PurchaseMoreThanAllocation() public {}

//     function test_PurchasePoolTokens_RevertWhen_CapExceeded() public {}

//     function test_PurchasePoolTokens_Pool() public {}

//     /*//////////////////////////////////////////////////////////////
//                             purchasePoolTokensWithNft
//     //////////////////////////////////////////////////////////////*/

//     function test_PurchasePoolTokensWithNft_RevertWhen_NotInPurchaseWindow() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_HasNoNftList() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_CollectionNotInPool() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_WalletAlreadyUsed() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_PurchaseMoreThanAllocation() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_CapExceeded() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_NotERC721Owner() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_ERC720TokenIdAlreadyUsed() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_ERC1155TokenIdNotInPool() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_ERC1155BalanceTooLow() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_NotPunkOwner() public {}

//     function test_PurchasePoolTokensWithNft_RevertWhen_PunkTokenIdAlreadyUsed() public {}

//     function test_PurchasePoolTokensWithNft_PoolERC721() public {}

//     function test_PurchasePoolTokensWithNft_PoolPunks() public {}

//     function test_PurchasePoolTokensWithNft_PoolERC721AndPunks() public {}

//     function test_PurchasePoolTokensWithNft_PoolERC1155() public {}

//     /*//////////////////////////////////////////////////////////////
//                             withdrawFromPool
//     //////////////////////////////////////////////////////////////*/

//     function test_WithdrawFromPool_RevertWhen_AmountTooHigh() public {}

//     function test_WithdrawFromPool_RevertWhen_NotInWithdrawWindow() public {}

//     function test_WithdrawFromPool_Pool() public {}

//     function test_WithdrawFromPool_PoolERC721() public {}

//     function test_WithdrawFromPool_Pool1155() public {}

//     /*//////////////////////////////////////////////////////////////
//                             withdrawMaxFromPool
//     //////////////////////////////////////////////////////////////*/

//     function test_WithdrawMaxFromPool_Pool() public {}

//     /*//////////////////////////////////////////////////////////////
//                             createDeal
//     //////////////////////////////////////////////////////////////*/

//     function test_CreateDeal_RevertWhen_NotSponsor() public {}

//     function test_CreateDeal_RevertWhen_DealNotReady() public {}

//     function test_CreateDeal_RevertWhen_TooManyDeals() public {}

//     function test_CreateDeal_RevertWhen_HolderIsNull() public {}

//     function test_CreateDeal_RevertWhen_UnderLyingTokenIsNull() public {}

//     function test_CreateDeal_RevertWhen_InPurchaseMode() public {}

//     function test_CreateDeal_RevertWhen_IncorrectProRataDedemptionPeriod() public {}

//     function test_CreateDeal_RevertWhen_IncorrectVestingCliffPeriod() public {}

//     function test_CreateDeal_RevertWhen_IncorrectVestingPeriod() public {}

//     function test_CreateDeal_RevertWhen_IncorrectFundingDuration() public {}

//     function test_CreateDeal_RevertWhen_TooMuchPurchaseTokensForDeal() public {}

//     function test_CreateDeal_RevertWhen_IncorrectOpenRedemptionPeriod() public {}

//     function test_CreateDeal_Pool() public {}

//     function test_CreateDeal_PoolERC721() public {}

//     function test_CreateDeal_PoolERC1155() public {}

//     /*//////////////////////////////////////////////////////////////
//                             acceptDealTokens
//     //////////////////////////////////////////////////////////////*/

//     function test_AcceptDealTokens_RevertWhen_DealNotFunded() public {}

//     function test_AcceptDealTokens_RevertWhen_NotInRedeemWindow() public {}

//     function test_AcceptDealTokens_RevertWhen_MoreThanProRataShare() public {}

//     function test_AcceptDealTokens_RevertWhen_NotEligibleOpenPeriod() public {}

//     function test_AcceptDealTokens_RevertWhen_OpenPeriodSoldOut() public {}

//     function test_AcceptDealTokens_RevertWhen_MoreThanOpenPeriodShare() public {}

//     function test_AcceptDealTokens_Pool() public {}

//     function test_AcceptDealTokens_PoolERC721() public {}

//     function test_AcceptDealTokens_PoolERC1155() public {}

//     /*//////////////////////////////////////////////////////////////
//                             acceptMaxDealTokens
//     //////////////////////////////////////////////////////////////*/

//     function test_AcceptMaxDealTokens_Pool() public {}

//     /*//////////////////////////////////////////////////////////////
//                             maxProRataAmount
//     //////////////////////////////////////////////////////////////*/

//     function test_MaxProRata_Pool() public {}

//     /*//////////////////////////////////////////////////////////////
//                             maxDealAccept
//     //////////////////////////////////////////////////////////////*/

//     function test_MaxDealAccept_Pool() public {}

//     /*//////////////////////////////////////////////////////////////
//                             transfer
//     //////////////////////////////////////////////////////////////*/

//     function test_Transfer_RevertWhen_NotInTransferWindow() public {}

//     function test_Transfer_RevertWhen_NoPoolToken() public {}

//     function test_Transfer() public {}

//     /*//////////////////////////////////////////////////////////////
//                             transferFrom
//     //////////////////////////////////////////////////////////////*/
//     function test_TransferFrom_RevertWhen_NotInTransferWindow() public {}

//     function test_TransferFrom_RevertWhen_NoPoolToken() public {}

//     function test_TransferFrom() public {}

//     /*//////////////////////////////////////////////////////////////
//                            setSponsor & acceptSponsor
//     //////////////////////////////////////////////////////////////*/

//     function test_SetSponsor_RevertWhen_NotSponsor() public {}

//     function test_SetSponsor_RevertWhen_SponsorIsNull() public {}

//     function test_AcceptSponsor_RevertWhen_NotDesignatedSponsor() public {}

//     function test_SetSponsor_AcceptSponsor() public {}

//     /*//////////////////////////////////////////////////////////////
//                             vouch & disavow
//     //////////////////////////////////////////////////////////////*/

//     function test_Vouch() public {}

//     function test_Disavow() public {}
// }
