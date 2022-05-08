// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/test.sol";
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
        vm.assume(sponsorFee < 98e18);
        vm.assume(duration <= 365 days);

        IAelinPool.NftData[] memory nftData;

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
            nftData: nftData
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
        address[] memory tmpAllowListAddresses = new address[](3);
        uint256[] memory tmpAllowListAmounts = new uint256[](3);

        tmpAllowListAddresses[0] = address(0x1337);
        tmpAllowListAddresses[1] = address(0xBEEF);
        tmpAllowListAddresses[2] = address(0xDEED);

        tmpAllowListAmounts[0] = 1e18;
        tmpAllowListAmounts[1] = 1e18;
        tmpAllowListAmounts[2] = 1e18;

        IAelinPool.NftData[] memory nftData;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: tmpAllowListAddresses,
            allowListAmounts: tmpAllowListAmounts,
            nftData: nftData
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

        for (uint256 i; i < tmpAllowListAddresses.length; ) {
            assertEq(AelinPool(poolAddress).allowList(tmpAllowListAddresses[i]), tmpAllowListAmounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function testCreatePoolWith721() public {
        IAelinPool.NftData[] memory nftData = new IAelinPool.NftData[](2);

        nftData[0].collectionAddress = address(collectionAddress1);
        nftData[0].purchaseAmount = 1e20;
        nftData[0].purchaseAmountPerToken = true;

        nftData[1].collectionAddress = address(collectionAddress2);
        nftData[1].purchaseAmount = 1e22;
        nftData[1].purchaseAmountPerToken = false;

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
            nftData: nftData
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 tmpPurchaseAmount1, address tmpCollection1, bool tmpPerToken1, uint256 tmpMinTokensEligible1) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(collectionAddress1));
        (uint256 tmpPurchaseAmount2, address tmpCollection2, bool tmpPerToken2, uint256 tmpMinTokensEligible2) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(collectionAddress2));

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
        assertEq(tmpPurchaseAmount1, 1e20);
        assertEq(tmpPurchaseAmount2, 1e22);
        assertEq(tmpCollection1, address(collectionAddress1));
        assertEq(tmpCollection2, address(collectionAddress2));
        assertTrue(tmpPerToken1);
        assertTrue(!tmpPerToken2);
        assertEq(tmpMinTokensEligible1, 0);
        assertEq(tmpMinTokensEligible2, 0);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
    }

    function testCreatePoolWithPunksAnd721() public {
        IAelinPool.NftData[] memory nftData = new IAelinPool.NftData[](2);

        nftData[0].collectionAddress = address(collectionAddress1);
        nftData[0].purchaseAmount = 1e20;
        nftData[0].purchaseAmountPerToken = true;

        nftData[1].collectionAddress = address(punks);
        nftData[1].purchaseAmount = 1e22;
        nftData[1].purchaseAmountPerToken = false;

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
            nftData: nftData
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 tmpPurchaseAmount1, address tmpCollection1, bool tmpPerToken1, uint256 tmpMinTokensEligible1) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(collectionAddress1));
        (uint256 tmpPurchaseAmount2, address tmpCollection2, bool tmpPerToken2, uint256 tmpMinTokensEligible2) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(punks));

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
        assertEq(tmpPurchaseAmount1, 1e20);
        assertEq(tmpPurchaseAmount2, 1e22);
        assertEq(tmpCollection1, address(collectionAddress1));
        assertEq(tmpCollection2, address(punks));
        assertTrue(tmpPerToken1);
        assertTrue(!tmpPerToken2);
        assertEq(tmpMinTokensEligible1, 0);
        assertEq(tmpMinTokensEligible2, 0);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
    }

    function testCreatePoolWith1155() public {
        IAelinPool.NftData[] memory nftData = new IAelinPool.NftData[](2);

        nftData[0].collectionAddress = address(collectionAddress3);
        nftData[0].purchaseAmount = 1e20;
        nftData[0].purchaseAmountPerToken = true;
        nftData[0].tokenIds = new uint256[](2);
        nftData[0].tokenIds[0] = 1;
        nftData[0].tokenIds[1] = 2;
        nftData[0].minTokensEligible = 100;

        nftData[1].collectionAddress = address(collectionAddress4);
        nftData[1].purchaseAmount = 1e22;
        nftData[1].purchaseAmountPerToken = false;
        nftData[1].tokenIds = new uint256[](2);
        nftData[1].tokenIds[0] = 10;
        nftData[1].tokenIds[1] = 20;
        nftData[1].minTokensEligible = 1000;

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
            nftData: nftData
        });

        address poolAddress = poolFactory.createPool(poolData);

        (uint256 tmpPurchaseAmount1, address tmpCollection1, bool tmpPerToken1, uint256 tmpMinTokensEligible1) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(collectionAddress3));
        (uint256 tmpPurchaseAmount2, address tmpCollection2, bool tmpPerToken2, uint256 tmpMinTokensEligible2) = AelinPool(
            poolAddress
        ).nftCollectionDetails(address(collectionAddress4));

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
        assertEq(tmpPurchaseAmount1, 1e20);
        assertEq(tmpPurchaseAmount2, 1e22);
        assertEq(tmpCollection1, address(collectionAddress3));
        assertEq(tmpCollection2, address(collectionAddress4));
        assertTrue(tmpPerToken1);
        assertTrue(!tmpPerToken2);
        assertEq(tmpMinTokensEligible1, 100);
        assertEq(tmpMinTokensEligible2, 1000);
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
        assertTrue(AelinPool(poolAddress).nftId(tmpCollection1, 1));
        assertTrue(AelinPool(poolAddress).nftId(tmpCollection1, 2));
        assertTrue(AelinPool(poolAddress).nftId(tmpCollection2, 10));
        assertTrue(AelinPool(poolAddress).nftId(tmpCollection2, 10));
    }

    function testFuzzCreatePoolTimestamp(uint256 timestamp) public {
        vm.assume(timestamp < 1e77);

        IAelinPool.NftData[] memory nftData;

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
            nftData: nftData
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
}
