// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockPunks} from "../mocks/MockPunks.sol";

contract AelinPoolTest is Test, AelinTestUtils {
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    AelinPoolFactory public poolFactory;
    AelinDeal public testDeal;

    enum NftCollectionType {
        ERC1155,
        ERC721
    }

    event PurchasePoolToken(address indexed purchaser, uint256 purchaseTokenAmount);

    function setUp() public {
        deal(address(purchaseToken), address(this), type(uint256).max);
        deal(address(underlyingDealToken), address(this), type(uint256).max);
        deal(address(purchaseToken), address(user1), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            purchasePoolTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchasePoolTokens_RevertWhen_NotInPurchaseWindow(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.warp(block.timestamp + _purchaseDuration);
        vm.expectRevert("not in purchase window");
        pool.purchasePoolTokens(10);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_HasNftList(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.expectRevert("has NFT list");
        pool.purchasePoolTokens(10);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_PurchaseMoreThanAllocation(
        uint256 _allowListAmount,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_purchaseTokenAmount > _allowListAmount);

        address[] memory allowListAddresses = new address[](1);
        uint256[] memory allowListAmounts = new uint256[](1);

        allowListAddresses[0] = address(user1);
        allowListAmounts[0] = _allowListAmount;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.expectRevert("more than allocation");
        pool.purchasePoolTokens(_purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_CapExceeded(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount > _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), type(uint256).max);
        vm.expectRevert("cap has been exceeded");
        pool.purchasePoolTokens(_purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokens_Pool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true, address(pool));
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokens(_purchaseTokenAmount);

        assertEq(pool.balanceOf(user1), _purchaseTokenAmount, "user got correct amount of pool tokens");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            purchasePoolTokensWithNft
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotInPurchaseWindow(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.warp(block.timestamp + _purchaseDuration);
        vm.expectRevert("not in purchase window");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_HasNoNftList(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.expectRevert("pool does not have an NFT list");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_CollectionNotInPool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("collection not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_WalletAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collection721_1);
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 1 days,
            sponsorFee: _sponsorFee,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collection721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.expectRevert("wallet already used for nft set");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_PurchaseMoreThanAllocation(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collection721_2);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("collection not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_CapExceeded(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount > _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collection721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        vm.expectRevert("cap has been exceeded");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotERC721Owner(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collection721_1).mint(user2, 1);
        vm.expectRevert("has to be the token owner");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC720TokenIdAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collection721_1);
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collection721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        MockERC721(collection721_1).transferFrom(user1, user2, 1);
        vm.stopPrank();

        vm.startPrank(user2);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        vm.expectRevert("tokenId already used");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC1155TokenIdNotInPool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 3; // Not in pool

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("tokenId not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC1155BalanceTooLow(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible,
        uint256 _userNftBalance
    ) public {
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_userNftBalance > 0);
        vm.assume(_minTokensEligible > _userNftBalance);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();
        nftCollectionRules[0].minTokensEligible[0] = _minTokensEligible;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: 0,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("erc1155 balance too low");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotPunkOwner(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = pseudoRandom;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("not the owner");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_PunkTokenIdAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenCap > 0);
        vm.assume(_purchaseTokenCap > _purchaseTokenAmount);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.expectRevert("tokenId already used");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC721(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockERC721(collection721_1).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);

        assertEq(pool.balanceOf(user1), _purchaseTokenAmount, "user got correct amount of pool tokens");
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolPunks(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);

        assertEq(pool.balanceOf(user1), _purchaseTokenAmount, "user got correct amount of pool tokens");
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC721AndPunks(uint256 _purchaseTokenCap, uint256 _purchaseTokenAmount)
        public
    {
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount <= 1000 ether);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        nftPurchaseList[1].collectionAddress = address(collection721_2);
        nftPurchaseList[1].tokenIds = new uint256[](1);
        nftPurchaseList[1].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        MockERC721(collection721_2).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);

        assertEq(pool.balanceOf(user1), _purchaseTokenAmount, "user got correct amount of pool tokens");
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC1155(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collection1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockERC1155(collection1155_1).mint(user1, 1, 100, "");
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);

        assertEq(pool.balanceOf(user1), _purchaseTokenAmount, "user got correct amount of pool tokens");
        vm.stopPrank();
    }
}
