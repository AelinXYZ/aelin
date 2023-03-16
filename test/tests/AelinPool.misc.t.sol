// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockPunks} from "../mocks/MockPunks.sol";

contract AelinPoolTest is Test, AelinTestUtils {
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    uint256 public constant MAX_UINT_SAFE = 10_000_000_000_000_000_000_000_000;

    AelinDeal public testDeal;

    struct PoolVars {
        address[] allowListAddresses;
        uint256[] allowListAmounts;
        IAelinPool.NftCollectionRules[] nftCollectionRules;
        IAelinPool.PoolData poolData;
        AelinPool pool;
        AelinFeeEscrow escrow;
        IAelinPool.NftPurchaseList[] nftPurchaseList;
        address dealAddress;
    }

    struct BoundedVars {
        uint256 sponsorFee;
        uint256 purchaseDuration;
        uint256 poolDuration;
        uint256 purchaseTokenAmount;
        uint256 purchaseTokenCap;
        uint256 proRataRedemptionPeriod;
        uint256 openRedemptionPeriod;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        uint256 underlyingDealTokenTotal;
        uint256 holderFundingExpiry;
        uint256 purchaseTokenTotalForDeal;
    }

    struct ReducedBoundedVars {
        uint256 sponsorFee;
        uint256 purchaseDuration;
        uint256 poolDuration;
        uint256 purchaseTokenCap;
        uint256 purchaseTokenAmount;
        uint256 withdrawAmount;
    }

    enum PoolVarsNftCollection {
        ERC721,
        ERC1155,
        PUNKS,
        NONE
    }

    enum NftCollectionType {
        ERC1155,
        ERC721
    }

    function setUp() public {
        testDeal = new AelinDeal();
        deal(address(purchaseToken), address(this), type(uint256).max);
        deal(address(underlyingDealToken), address(this), type(uint256).max);
        deal(address(purchaseToken), address(user1), type(uint256).max);
    }

    event AcceptDeal(
        address indexed purchaser,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee
    );

    event WithdrawFromPool(address indexed purchaser, uint256 purchaseTokenAmount);

    /*//////////////////////////////////////////////////////////////
                            helpers
    //////////////////////////////////////////////////////////////*/

    function getPoolVars(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        PoolVarsNftCollection nftListType
    ) internal returns (PoolVars memory) {
        PoolVars memory poolVars;

        if (nftListType == PoolVarsNftCollection.ERC721) {
            poolVars.nftCollectionRules = getNft721CollectionRules();
            poolVars.nftCollectionRules[0].purchaseAmount = 0;
            poolVars.nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
            poolVars.nftPurchaseList[0].collectionAddress = address(collection721_1);
            poolVars.nftPurchaseList[0].tokenIds = new uint256[](1);
            poolVars.nftPurchaseList[0].tokenIds[0] = 1;
        }

        if (nftListType == PoolVarsNftCollection.ERC1155) {
            poolVars.nftCollectionRules = getNft1155CollectionRules();
            poolVars.nftCollectionRules[0].collectionAddress = address(collection1155_1);
            poolVars.nftCollectionRules[0].purchaseAmount = 0;
            poolVars.nftCollectionRules[0].purchaseAmountPerToken = false;
            poolVars.nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
            poolVars.nftPurchaseList[0].collectionAddress = address(collection1155_1);
            poolVars.nftPurchaseList[0].tokenIds = new uint256[](1);
            poolVars.nftPurchaseList[0].tokenIds[0] = 1;
        }

        poolVars.poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: poolVars.allowListAddresses,
            allowListAmounts: poolVars.allowListAmounts,
            nftCollectionRules: poolVars.nftCollectionRules
        });
        poolVars.pool = new AelinPool();
        poolVars.escrow = new AelinFeeEscrow();

        poolVars.pool.initialize(poolVars.poolData, user1, address(testDeal), aelinTreasury, address(poolVars.escrow));

        return poolVars;
    }

    function boundVariables(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) internal returns (BoundedVars memory) {
        BoundedVars memory boundedVars;

        boundedVars.sponsorFee = bound(_sponsorFee, 0, MAX_SPONSOR_FEE);
        boundedVars.purchaseDuration = bound(_purchaseDuration, 30 minutes, 30 days);
        boundedVars.poolDuration = bound(_poolDuration, 0, 365 days);
        boundedVars.purchaseTokenCap = bound(_purchaseTokenCap, 100, MAX_UINT_SAFE);
        boundedVars.proRataRedemptionPeriod = bound(_proRataRedemptionPeriod, 30 minutes, 30 days);
        boundedVars.openRedemptionPeriod = bound(_openRedemptionPeriod, 30 minutes, 30 days);
        boundedVars.vestingPeriod = bound(_vestingPeriod, 0, 1825 days);
        boundedVars.vestingCliffPeriod = bound(_vestingCliffPeriod, 0, 1825 days);
        boundedVars.underlyingDealTokenTotal = bound(_underlyingDealTokenTotal, 1, MAX_UINT_SAFE);
        boundedVars.holderFundingExpiry = bound(_holderFundingExpiry, 30 minutes, 30 days);
        if (_purchaseTokenCap > 0) {
            boundedVars.purchaseTokenAmount = bound(_purchaseTokenAmount, 1, boundedVars.purchaseTokenCap);
        } else {
            boundedVars.purchaseTokenAmount = bound(_purchaseTokenAmount, 1, MAX_UINT_SAFE);
        }

        boundedVars.purchaseTokenTotalForDeal = bound(_purchaseTokenTotalForDeal, 1, boundedVars.purchaseTokenAmount);

        // Assume only for narrow checking
        vm.assume(boundedVars.purchaseTokenCap > boundedVars.purchaseTokenAmount);
        vm.assume(boundedVars.purchaseTokenTotalForDeal != boundedVars.purchaseTokenAmount);

        return boundedVars;
    }

    function reducedBoundVariables(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) internal returns (ReducedBoundedVars memory) {
        ReducedBoundedVars memory boundedVars;

        vm.assume(_purchaseTokenAmount < _withdrawAmount);

        boundedVars.sponsorFee = bound(_sponsorFee, 0, MAX_SPONSOR_FEE);
        boundedVars.purchaseDuration = bound(_purchaseDuration, 30 minutes, 30 days);
        boundedVars.poolDuration = bound(_poolDuration, 0, 365 days);
        boundedVars.purchaseTokenCap = bound(_purchaseTokenCap, 100, MAX_UINT_SAFE);
        if (_purchaseTokenCap > 0) {
            boundedVars.purchaseTokenAmount = bound(_purchaseTokenAmount, 1, boundedVars.purchaseTokenCap);
        } else {
            boundedVars.purchaseTokenAmount = bound(_purchaseTokenAmount, 1, MAX_UINT_SAFE);
        }

        boundedVars.withdrawAmount = bound(_withdrawAmount, 1, boundedVars.purchaseTokenAmount);

        // Assume only for narrow checking
        vm.assume(boundedVars.purchaseTokenCap > boundedVars.purchaseTokenAmount);

        return boundedVars;
    }

    /*//////////////////////////////////////////////////////////////
                            createDeal
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CreateDeal_RevertWhen_NotSponsor(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            1,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );
        vm.warp(boundedVars.purchaseDuration + 1);

        // Assert
        vm.startPrank(user2);
        vm.expectRevert("only sponsor can access");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_DealNotReady(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        // A) Holder funding not expired yet
        vm.expectRevert("cant create new deal");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        // B) Holder funded the deal
        vm.startPrank(user2);
        MockERC20(underlyingDealToken).approve(poolVars.dealAddress, type(uint256).max);
        deal(address(underlyingDealToken), user2, type(uint256).max);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.warp(block.timestamp + boundedVars.holderFundingExpiry + 1);
        assertTrue(block.timestamp >= poolVars.pool.holderFundingExpiry()); // Holder funding expired

        vm.startPrank(user1);
        vm.expectRevert("cant create new deal");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_TooManyDeals(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        for (uint256 i; i < 5; ++i) {
            poolVars.pool.createDeal(
                address(underlyingDealToken),
                boundedVars.purchaseTokenTotalForDeal,
                boundedVars.underlyingDealTokenTotal,
                boundedVars.vestingPeriod,
                boundedVars.vestingCliffPeriod,
                boundedVars.proRataRedemptionPeriod,
                boundedVars.openRedemptionPeriod,
                user2,
                boundedVars.holderFundingExpiry
            );

            vm.warp(block.timestamp + boundedVars.holderFundingExpiry + 1);
        }

        vm.expectRevert("too many deals");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_HolderIsNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("cant pass null holder address");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            address(0),
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_UnderLyingTokenIsNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("cant pass null token address");
        poolVars.pool.createDeal(
            address(0),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_InPurchaseMode(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);

        vm.expectRevert("pool still in purchase mode");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_IncorrectProRataDedemptionPeriod(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        // Incorrect proRataRedemptionPeriod
        vm.assume(_proRataRedemptionPeriod < 30 minutes || _proRataRedemptionPeriod > 30 days);
        boundedVars.proRataRedemptionPeriod = _proRataRedemptionPeriod;

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("30 mins - 30 days for prorata");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_IncorrectVestingCliffPeriod(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        // Incorrect vestingCliffPeriod
        boundedVars.vestingCliffPeriod = bound(_vestingCliffPeriod, 1826 days, MAX_UINT_SAFE);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("max 5 year cliff");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_IncorrectVestingPeriod(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        // Incorrect vestingPeriod
        boundedVars.vestingPeriod = bound(_vestingPeriod, 1826 days, MAX_UINT_SAFE);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("max 5 year vesting");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_IncorrectFundingDuration(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        // Incorrect _holderFundingExpiry
        vm.assume(_holderFundingExpiry < 30 minutes || _holderFundingExpiry > 30 days);
        boundedVars.holderFundingExpiry = _holderFundingExpiry;

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );
        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("30 mins - 30 days for holder");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_TooMuchPurchaseTokensForDeal(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        boundedVars.purchaseTokenTotalForDeal = bound(
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.purchaseTokenAmount + 1,
            MAX_UINT_SAFE
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("not enough funds available");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_RevertWhen_IncorrectOpenRedemptionPeriod(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        // Incorrect _openRedemptionPeriod
        vm.assume(_openRedemptionPeriod < 30 minutes || _openRedemptionPeriod > 30 days);
        boundedVars.openRedemptionPeriod = _openRedemptionPeriod;

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        vm.expectRevert("30 mins - 30 days for open");
        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_Pool(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        (uint256 proRataPeriod, , ) = AelinDeal(poolVars.dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(poolVars.dealAddress).openRedemption();

        assertEq(poolVars.pool.numberOfDeals(), 1, "number of deals");
        assertEq(poolVars.pool.poolExpiry(), block.timestamp, "pool expiry");
        assertEq(poolVars.pool.holder(), user2, "holder address");
        assertEq(
            poolVars.pool.holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry"
        );
        assertEq(
            poolVars.pool.purchaseTokenTotalForDeal(),
            boundedVars.purchaseTokenTotalForDeal,
            "purchase token total for deal"
        );
        assertEq(AelinDeal(poolVars.dealAddress).holder(), user2, "holder address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealToken(),
            address(underlyingDealToken),
            "underlying deal token address"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealTokenTotal(),
            boundedVars.underlyingDealTokenTotal,
            "underlying deal token total"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            boundedVars.purchaseTokenTotalForDeal * 10**(18 - purchaseToken.decimals()),
            "deal max total supply"
        );
        assertEq(AelinDeal(poolVars.dealAddress).aelinPool(), address(poolVars.pool), "aelin pool address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).vestingCliffPeriod(),
            boundedVars.vestingCliffPeriod,
            "vesting cliff period"
        );
        assertEq(AelinDeal(poolVars.dealAddress).vestingPeriod(), boundedVars.vestingPeriod, "vesting period");
        assertEq(proRataPeriod, boundedVars.proRataRedemptionPeriod, "pro rata period");
        assertEq(openPeriod, boundedVars.openRedemptionPeriod, "open period");
        assertEq(
            AelinDeal(poolVars.dealAddress).holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).aelinTreasuryAddress(),
            address(aelinTreasury),
            "aelin treasury address (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingPerDealExchangeRate(),
            (boundedVars.underlyingDealTokenTotal * 1e18) / AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            "underlying per deal exchange rate"
        );
        assertFalse(AelinDeal(poolVars.dealAddress).depositComplete(), "deposit completed");

        vm.stopPrank();
    }

    function testFuzz_CreateDeal_PoolERC721(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC721
        );

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        MockERC721(collection721_1).mint(user1, 1);
        poolVars.pool.purchasePoolTokensWithNft(poolVars.nftPurchaseList, boundedVars.purchaseTokenAmount);

        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        (uint256 proRataPeriod, , ) = AelinDeal(poolVars.dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(poolVars.dealAddress).openRedemption();

        assertEq(poolVars.pool.numberOfDeals(), 1, "number of deals");
        assertEq(poolVars.pool.poolExpiry(), block.timestamp, "pool expiry");
        assertEq(poolVars.pool.holder(), user2, "holder address");
        assertEq(
            poolVars.pool.holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry"
        );
        assertEq(
            poolVars.pool.purchaseTokenTotalForDeal(),
            boundedVars.purchaseTokenTotalForDeal,
            "purchase token total for deal"
        );
        assertEq(AelinDeal(poolVars.dealAddress).holder(), user2, "holder address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealToken(),
            address(underlyingDealToken),
            "underlying deal token address"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealTokenTotal(),
            boundedVars.underlyingDealTokenTotal,
            "underlying deal token total"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            boundedVars.purchaseTokenTotalForDeal * 10**(18 - purchaseToken.decimals()),
            "deal max total supply"
        );
        assertEq(AelinDeal(poolVars.dealAddress).aelinPool(), address(poolVars.pool), "aelin pool address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).vestingCliffPeriod(),
            boundedVars.vestingCliffPeriod,
            "vesting cliff period"
        );
        assertEq(AelinDeal(poolVars.dealAddress).vestingPeriod(), boundedVars.vestingPeriod, "vesting period");
        assertEq(proRataPeriod, boundedVars.proRataRedemptionPeriod, "pro rata period");
        assertEq(openPeriod, boundedVars.openRedemptionPeriod, "open period");
        assertEq(
            AelinDeal(poolVars.dealAddress).holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).aelinTreasuryAddress(),
            address(aelinTreasury),
            "aelin treasury address (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingPerDealExchangeRate(),
            (boundedVars.underlyingDealTokenTotal * 1e18) / AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            "underlying per deal exchange rate"
        );
        assertFalse(AelinDeal(poolVars.dealAddress).depositComplete(), "deposit completed");
        vm.stopPrank();
    }

    function testFuzz_CreateDeal_PoolERC1155(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC1155
        );

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        MockERC1155(collection1155_1).mint(user1, 1, 100, "");
        poolVars.pool.purchasePoolTokensWithNft(poolVars.nftPurchaseList, boundedVars.purchaseTokenAmount);

        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        (uint256 proRataPeriod, , ) = AelinDeal(poolVars.dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(poolVars.dealAddress).openRedemption();

        assertEq(poolVars.pool.numberOfDeals(), 1, "number of deals");
        assertEq(poolVars.pool.poolExpiry(), block.timestamp, "pool expiry");
        assertEq(poolVars.pool.holder(), user2, "holder address");
        assertEq(
            poolVars.pool.holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry"
        );
        assertEq(
            poolVars.pool.purchaseTokenTotalForDeal(),
            boundedVars.purchaseTokenTotalForDeal,
            "purchase token total for deal"
        );
        assertEq(AelinDeal(poolVars.dealAddress).holder(), user2, "holder address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealToken(),
            address(underlyingDealToken),
            "underlying deal token address"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingDealTokenTotal(),
            boundedVars.underlyingDealTokenTotal,
            "underlying deal token total"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            boundedVars.purchaseTokenTotalForDeal * 10**(18 - purchaseToken.decimals()),
            "deal max total supply"
        );
        assertEq(AelinDeal(poolVars.dealAddress).aelinPool(), address(poolVars.pool), "aelin pool address (deal)");
        assertEq(
            AelinDeal(poolVars.dealAddress).vestingCliffPeriod(),
            boundedVars.vestingCliffPeriod,
            "vesting cliff period"
        );
        assertEq(AelinDeal(poolVars.dealAddress).vestingPeriod(), boundedVars.vestingPeriod, "vesting period");
        assertEq(proRataPeriod, boundedVars.proRataRedemptionPeriod, "pro rata period");
        assertEq(openPeriod, boundedVars.openRedemptionPeriod, "open period");
        assertEq(
            AelinDeal(poolVars.dealAddress).holderFundingExpiry(),
            block.timestamp + boundedVars.holderFundingExpiry,
            "holder funding expiry (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).aelinTreasuryAddress(),
            address(aelinTreasury),
            "aelin treasury address (deal)"
        );
        assertEq(
            AelinDeal(poolVars.dealAddress).underlyingPerDealExchangeRate(),
            (boundedVars.underlyingDealTokenTotal * 1e18) / AelinDeal(poolVars.dealAddress).maxTotalSupply(),
            "underlying per deal exchange rate"
        );
        assertFalse(AelinDeal(poolVars.dealAddress).depositComplete(), "deposit completed");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawFromPool
    //////////////////////////////////////////////////////////////*/

    function testFuzz_WithdrawFromPool_RevertWhen_AmountTooHigh(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _withdrawAmount
        );

        boundedVars.withdrawAmount = bound(_withdrawAmount, boundedVars.purchaseTokenAmount, MAX_UINT_SAFE);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);

        vm.expectRevert("input larger than balance");
        poolVars.pool.withdrawFromPool(boundedVars.withdrawAmount);
        vm.stopPrank();
    }

    function testFuzz_WithdrawFromPool_RevertWhen_NotInWithdrawPerdiod(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _withdrawAmount
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);

        vm.expectRevert("not yet withdraw period");
        poolVars.pool.withdrawFromPool(boundedVars.withdrawAmount);
        vm.stopPrank();
    }

    function testFuzz_WithdrawFromPool_RevertWhen_InFundingPeriod(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _withdrawAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        _withdrawAmount = bound(_withdrawAmount, 1, boundedVars.purchaseTokenAmount);
        boundedVars.holderFundingExpiry = bound(_holderFundingExpiry, boundedVars.purchaseDuration + 1, 30 days);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );

        vm.warp(boundedVars.holderFundingExpiry + 1);

        vm.expectRevert("cant withdraw in funding period");
        poolVars.pool.withdrawFromPool(_withdrawAmount);
        vm.stopPrank();

        assertFalse(block.timestamp > poolVars.pool.holderFundingExpiry(), "holderFundingExpiry");
        assertFalse(AelinDeal(poolVars.dealAddress).depositComplete(), "deposit not complete");
    }

    function testFuzz_WithdrawFromPool_Pool(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _withdrawAmount
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(block.timestamp + boundedVars.purchaseDuration + boundedVars.poolDuration + 1);

        vm.expectEmit(true, true, true, true, address(poolVars.pool));
        emit WithdrawFromPool(user1, boundedVars.withdrawAmount);
        poolVars.pool.withdrawFromPool(boundedVars.withdrawAmount);

        assertEq(poolVars.pool.balanceOf(user1), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(poolVars.pool.amountWithdrawn(user1), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalAmountWithdrawn(), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalSupply(), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(
            MockERC20(purchaseToken).balanceOf(user1),
            type(uint256).max - boundedVars.purchaseTokenAmount + boundedVars.withdrawAmount
        );
        vm.stopPrank();
    }

    function testFuzz_WithdrawFromPool_PoolERC721(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _withdrawAmount
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC721
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        MockERC721(collection721_1).mint(user1, 1);
        poolVars.pool.purchasePoolTokensWithNft(poolVars.nftPurchaseList, boundedVars.purchaseTokenAmount);
        vm.warp(block.timestamp + boundedVars.purchaseDuration + boundedVars.poolDuration + 1);

        vm.expectEmit(true, true, true, true, address(poolVars.pool));
        emit WithdrawFromPool(user1, boundedVars.withdrawAmount);
        poolVars.pool.withdrawFromPool(boundedVars.withdrawAmount);

        assertEq(poolVars.pool.balanceOf(user1), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(poolVars.pool.amountWithdrawn(user1), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalAmountWithdrawn(), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalSupply(), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(
            MockERC20(purchaseToken).balanceOf(user1),
            type(uint256).max - boundedVars.purchaseTokenAmount + boundedVars.withdrawAmount
        );
        vm.stopPrank();
    }

    function testFuzz_WithdrawFromPool_PoolERC1155(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _withdrawAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _withdrawAmount
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC1155
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        MockERC1155(collection1155_1).mint(user1, 1, 100, "");
        poolVars.pool.purchasePoolTokensWithNft(poolVars.nftPurchaseList, boundedVars.purchaseTokenAmount);
        vm.warp(block.timestamp + boundedVars.purchaseDuration + boundedVars.poolDuration + 1);

        vm.expectEmit(true, true, true, true, address(poolVars.pool));
        emit WithdrawFromPool(user1, boundedVars.withdrawAmount);
        poolVars.pool.withdrawFromPool(boundedVars.withdrawAmount);

        assertEq(poolVars.pool.balanceOf(user1), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(poolVars.pool.amountWithdrawn(user1), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalAmountWithdrawn(), boundedVars.withdrawAmount);
        assertEq(poolVars.pool.totalSupply(), boundedVars.purchaseTokenAmount - boundedVars.withdrawAmount);
        assertEq(
            MockERC20(purchaseToken).balanceOf(user1),
            type(uint256).max - boundedVars.purchaseTokenAmount + boundedVars.withdrawAmount
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawMaxFromPool
    //////////////////////////////////////////////////////////////*/

    function testFuzz_WithdrawMaxFromPool_Pool(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount
    ) public {
        ReducedBoundedVars memory boundedVars = reducedBoundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _purchaseTokenAmount
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(block.timestamp + boundedVars.purchaseDuration + boundedVars.poolDuration + 1);

        vm.expectEmit(true, true, true, true, address(poolVars.pool));
        emit WithdrawFromPool(user1, boundedVars.purchaseTokenAmount);
        poolVars.pool.withdrawFromPool(boundedVars.purchaseTokenAmount);

        assertEq(poolVars.pool.balanceOf(user1), 0);
        assertEq(poolVars.pool.amountWithdrawn(user1), boundedVars.purchaseTokenAmount);
        assertEq(poolVars.pool.totalAmountWithdrawn(), boundedVars.purchaseTokenAmount);
        assertEq(poolVars.pool.totalSupply(), 0);
        assertEq(MockERC20(purchaseToken).balanceOf(user1), type(uint256).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            acceptDealTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_AcceptDealTokens_RevertWhen_DealNotFunded(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _poolTokenAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), type(uint256).max);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert("deal not yet funded");
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_RevertWhen_NotInRedeemWindow(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _poolTokenAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.warp(block.timestamp + boundedVars.openRedemptionPeriod + boundedVars.proRataRedemptionPeriod);
        vm.expectRevert("outside of redeem window");
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_RevertWhen_MoreThanProRataShare(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _poolTokenAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.assume(
            _poolTokenAmount > boundedVars.purchaseTokenAmount || _poolTokenAmount > poolVars.pool.maxProRataAmount(user1)
        );
        vm.expectRevert("accepting more than share");
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_RevertWhen_NotEligibleOpenPeriod(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _poolTokenAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.warp(block.timestamp + boundedVars.proRataRedemptionPeriod);

        vm.startPrank(user1);
        vm.expectRevert("ineligible: didn't max pro rata");
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_RevertWhen_OpenPeriodSoldOut(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        vm.assume(boundedVars.purchaseTokenAmount > 1000);

        // Assert
        vm.startPrank(user3);
        deal(address(purchaseToken), address(user3), 1000);
        MockERC20(purchaseToken).approve(address(poolVars.pool), 1000);
        poolVars.pool.purchasePoolTokens(1000);
        vm.stopPrank();

        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount - 1000);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount - 1000);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.startPrank(user1);
        poolVars.pool.acceptDealTokens(poolVars.pool.maxProRataAmount(user1));

        vm.warp(block.timestamp + boundedVars.proRataRedemptionPeriod);

        if (poolVars.pool.balanceOf(user1) + poolVars.pool.totalAmountAccepted() <= boundedVars.purchaseTokenTotalForDeal) {
            poolVars.pool.acceptDealTokens(poolVars.pool.balanceOf(user1));
        } else {
            poolVars.pool.acceptDealTokens(boundedVars.purchaseTokenTotalForDeal - poolVars.pool.totalAmountAccepted());
        }

        vm.expectRevert("nothing left to accept");
        poolVars.pool.acceptDealTokens(1);
        vm.stopPrank();
    }

    function tes_AcceptDealTokens_RevertWhen_MoreThanOpenPeriodShare(
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _poolTokenAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            0,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.startPrank(user1);
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.warp(block.timestamp + boundedVars.proRataRedemptionPeriod);

        vm.expectRevert("accepting more than share");
        poolVars.pool.acceptDealTokens(_poolTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_Pool(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenAmount,
        uint256 _purchaseTokenCap,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _underlyingDealTokenTotal,
        uint256 _holderFundingExpiry,
        uint256 _purchaseTokenTotalForDeal
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _purchaseDuration,
            _poolDuration,
            _purchaseTokenAmount,
            _purchaseTokenCap,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _vestingPeriod,
            _vestingCliffPeriod,
            _underlyingDealTokenTotal,
            _holderFundingExpiry,
            _purchaseTokenTotalForDeal
        );

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        // Assert
        vm.startPrank(user1);
        MockERC20(purchaseToken).approve(address(poolVars.pool), boundedVars.purchaseTokenAmount);
        poolVars.pool.purchasePoolTokens(boundedVars.purchaseTokenAmount);
        vm.warp(boundedVars.purchaseDuration + 1);

        poolVars.dealAddress = poolVars.pool.createDeal(
            address(underlyingDealToken),
            boundedVars.purchaseTokenTotalForDeal,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            boundedVars.proRataRedemptionPeriod,
            boundedVars.openRedemptionPeriod,
            user2,
            boundedVars.holderFundingExpiry
        );
        vm.stopPrank();

        vm.startPrank(user2);
        deal(address(underlyingDealToken), address(user2), type(uint256).max);
        MockERC20(address(underlyingDealToken)).approve(address(poolVars.dealAddress), boundedVars.underlyingDealTokenTotal);
        AelinDeal(poolVars.dealAddress).depositUnderlying(boundedVars.underlyingDealTokenTotal);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 acceptedAmount = poolVars.pool.maxProRataAmount(user1);
        uint256 aelinFeeAmount = (acceptedAmount * 10**(18 - MockERC20(purchaseToken).decimals()) * AELIN_FEE) / BASE;
        uint256 sponsorFeeAmount = (acceptedAmount *
            10**(18 - MockERC20(purchaseToken).decimals()) *
            boundedVars.sponsorFee) / BASE;
        vm.expectEmit(true, true, true, true, address(poolVars.pool));
        emit AcceptDeal(user1, poolVars.dealAddress, acceptedAmount, sponsorFeeAmount, aelinFeeAmount);
        poolVars.pool.acceptDealTokens(acceptedAmount);

        assertEq(poolVars.pool.amountAccepted(user1), acceptedAmount);
        assertEq(poolVars.pool.totalAmountAccepted(), acceptedAmount);
        assertEq(MockERC20(purchaseToken).balanceOf(user2), acceptedAmount);
        vm.stopPrank();
    }

    function testFuzz_AcceptDealTokens_PoolERC721() public {}

    function testFuzz_AcceptDealTokens_PoolERC1155() public {}

    /*//////////////////////////////////////////////////////////////
                            acceptMaxDealTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_AcceptMaxDealTokens_Pool() public {}

    /*//////////////////////////////////////////////////////////////
                            maxProRataAmount
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MaxProRata_Pool() public {}

    /*//////////////////////////////////////////////////////////////
                            maxDealAccept
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MaxDealAccept_Pool() public {}
}
