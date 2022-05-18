// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";

contract AelinPoolFactoryTest is Test {
    address public aelinRewards = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    AelinPool public testPool;
    AelinDeal public testDeal;
    AelinPoolFactory public poolFactory;
    MockERC20 public purchaseToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;
    MockERC1155 public collectionAddress3;
    MockERC1155 public collectionAddress4;

    address[] public allowListAddresses;
    uint256[] public allowListAmounts;

    function setUp() public {
        testPool = new AelinPool();
        testDeal = new AelinDeal();
        poolFactory = new AelinPoolFactory(address(testPool), address(testDeal), aelinRewards);
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC1155("");
        collectionAddress4 = new MockERC1155("");

        assertEq(poolFactory.AELIN_POOL_LOGIC(), address(testPool));
        assertEq(poolFactory.AELIN_DEAL_LOGIC(), address(testDeal));
        assertEq(poolFactory.AELIN_REWARDS(), address(aelinRewards));
    }

    /*//////////////////////////////////////////////////////////////
                            createPool
    //////////////////////////////////////////////////////////////*/

    function testFuzzCreatePool(
        uint256 purchaseTokenCap,
        uint256 purchaseDuration,
        uint256 sponsorFee,
        uint256 duration
    ) public {
        vm.assume(purchaseTokenCap < 1e27);
        vm.assume(purchaseDuration >= 30 minutes);
        vm.assume(purchaseDuration <= 30 days);
        vm.assume(sponsorFee < 15e18);
        vm.assume(duration <= 365 days);

        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: purchaseTokenCap,
            purchaseToken: address(purchaseToken),
            duration: duration,
            sponsorFee: sponsorFee,
            purchaseDuration: purchaseDuration,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), purchaseTokenCap);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + purchaseDuration);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + purchaseDuration + duration);
        assertEq(AelinPool(poolAddress).sponsorFee(), sponsorFee);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
    }

    function testCreatePoolAddresses() public {
        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);

        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);

        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 1e18;
        testAllowListAmounts[2] = 1e18;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: testAllowListAddresses,
            allowListAmounts: testAllowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e27);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(AelinPool(poolAddress).hasAllowList());

        for (uint256 i; i < testAllowListAddresses.length; ) {
            assertEq(AelinPool(poolAddress).allowList(testAllowListAddresses[i]), testAllowListAmounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function testCreatePoolWith721() public {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);

        nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules[0].purchaseAmount = 1e20;
        nftCollectionRules[0].purchaseAmountPerToken = true;

        nftCollectionRules[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules[1].purchaseAmount = 1e22;
        nftCollectionRules[1].purchaseAmountPerToken = false;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 testPurchaseAmount1, address testCollection1, bool testPerToken1) = AelinPool(poolAddress)
            .nftCollectionDetails(address(collectionAddress1));
        (uint256 testPurchaseAmount2, address testCollection2, bool testPerToken2) = AelinPool(poolAddress)
            .nftCollectionDetails(address(collectionAddress2));

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e27);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(testPurchaseAmount1, 1e20);
        assertEq(testPurchaseAmount2, 1e22);
        assertEq(testCollection1, address(collectionAddress1));
        assertEq(testCollection2, address(collectionAddress2));
        assertTrue(testPerToken1);
        assertTrue(!testPerToken2);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
    }

    function testCreatePoolWithPunksAnd721() public {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);

        nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules[0].purchaseAmount = 1e20;
        nftCollectionRules[0].purchaseAmountPerToken = true;

        nftCollectionRules[1].collectionAddress = address(punks);
        nftCollectionRules[1].purchaseAmount = 1e22;
        nftCollectionRules[1].purchaseAmountPerToken = false;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 testPurchaseAmount1, address testCollection1, bool testPerToken1) = AelinPool(poolAddress)
            .nftCollectionDetails(address(collectionAddress1));
        (uint256 testPurchaseAmount2, address testCollection2, bool testPerToken2) = AelinPool(poolAddress)
            .nftCollectionDetails(address(punks));

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e27);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(testPurchaseAmount1, 1e20);
        assertEq(testPurchaseAmount2, 1e22);
        assertEq(testCollection1, address(collectionAddress1));
        assertEq(testCollection2, address(punks));
        assertTrue(testPerToken1);
        assertTrue(!testPerToken2);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
    }

    function testCreatePoolWith1155() public {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);

        nftCollectionRules[0].collectionAddress = address(collectionAddress3);
        nftCollectionRules[0].purchaseAmount = 1e20;
        nftCollectionRules[0].purchaseAmountPerToken = true;
        nftCollectionRules[0].tokenIds = new uint256[](2);
        nftCollectionRules[0].minTokensEligible = new uint256[](2);
        nftCollectionRules[0].tokenIds[0] = 1;
        nftCollectionRules[0].tokenIds[1] = 2;
        nftCollectionRules[0].minTokensEligible[0] = 100;
        nftCollectionRules[0].minTokensEligible[1] = 200;

        nftCollectionRules[1].collectionAddress = address(collectionAddress4);
        nftCollectionRules[1].purchaseAmount = 1e22;
        nftCollectionRules[1].purchaseAmountPerToken = false;
        nftCollectionRules[1].tokenIds = new uint256[](2);
        nftCollectionRules[1].minTokensEligible = new uint256[](2);
        nftCollectionRules[1].tokenIds[0] = 10;
        nftCollectionRules[1].tokenIds[1] = 20;
        nftCollectionRules[1].minTokensEligible[0] = 1000;
        nftCollectionRules[1].minTokensEligible[1] = 2000;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 testPurchaseAmount1, address testCollection1, bool testPerToken1) = AelinPool(poolAddress)
            .nftCollectionDetails(address(collectionAddress3));
        (uint256 testPurchaseAmount2, address testCollection2, bool testPerToken2) = AelinPool(poolAddress)
            .nftCollectionDetails(address(collectionAddress4));

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e27);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(testPurchaseAmount1, 1e20);
        assertEq(testPurchaseAmount2, 1e22);
        assertEq(testCollection1, address(collectionAddress3));
        assertEq(testCollection2, address(collectionAddress4));
        assertTrue(testPerToken1);
        assertTrue(!testPerToken2);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
        assertTrue(AelinPool(poolAddress).nftId(testCollection1, 1));
        assertTrue(AelinPool(poolAddress).nftId(testCollection1, 2));
        assertTrue(AelinPool(poolAddress).nftId(testCollection2, 10));
        assertTrue(AelinPool(poolAddress).nftId(testCollection2, 10));
    }

    function testFuzzCreatePoolTimestamp(uint256 timestamp) public {
        vm.assume(timestamp < 1e77);

        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e18,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        vm.warp(timestamp);
        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e18);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
    }

    // reverts when some an address other than 721 or 1155 is provided
    function testCreatePoolNonCompatibleAddress(uint256 timestamp, address collection) public {
        vm.assume(timestamp < 1e77);
        vm.assume(collection != address(collectionAddress1));
        vm.assume(collection != address(collectionAddress2));
        vm.assume(collection != address(collectionAddress3));
        vm.assume(collection != address(collectionAddress4));
        vm.assume(collection != punks);

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        nftCollectionRules[0].collectionAddress = collection;
        nftCollectionRules[0].purchaseAmount = 1e20;
        nftCollectionRules[0].purchaseAmountPerToken = true;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e18,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        vm.warp(timestamp);
        vm.expectRevert(bytes("collection is not compatible"));
        poolFactory.createPool(poolData);
    }
}
