// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICryptoPunks} from "contracts/interfaces/ICryptoPunks.sol";

contract AelinPoolPurchase is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWith1155;
    address public poolAddressWithPunks;

    AelinPoolFactory public poolFactory;

    MockERC20 public purchaseToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;
    MockERC721 public collectionAddress3;
    MockERC1155 public collectionAddress4;
    MockERC1155 public collectionAddress5;

    function setUp() public {
        poolFactory = new AelinPoolFactory(
            address(new AelinPool()),
            address(new AelinDeal()),
            aelinTreasury,
            address(new AelinFeeEscrow())
        );
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC721("TestCollection", "TC");
        collectionAddress4 = new MockERC1155("");
        collectionAddress5 = new MockERC1155("");

        deal(address(purchaseToken), address(this), 1e75);

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](3);
        IAelinPool.NftCollectionRules[] memory nftCollectionRules1155 = new IAelinPool.NftCollectionRules[](2);
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesPunks = new IAelinPool.NftCollectionRules[](2);

        nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        nftCollectionRules[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules[1].purchaseAmount = 1e22;
        nftCollectionRules[1].purchaseAmountPerToken = false;

        nftCollectionRules[2].collectionAddress = address(collectionAddress3);
        nftCollectionRules[2].purchaseAmount = 1e22;
        nftCollectionRules[2].purchaseAmountPerToken = true;

        nftCollectionRules1155[0].collectionAddress = address(collectionAddress4);
        nftCollectionRules1155[0].purchaseAmount = 1e22;
        nftCollectionRules1155[0].purchaseAmountPerToken = true;
        nftCollectionRules1155[0].tokenIds = new uint256[](2);
        nftCollectionRules1155[0].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[0].tokenIds[0] = 1;
        nftCollectionRules1155[0].tokenIds[1] = 2;
        nftCollectionRules1155[0].minTokensEligible[0] = 100;
        nftCollectionRules1155[0].minTokensEligible[1] = 200;

        nftCollectionRules1155[1].collectionAddress = address(collectionAddress5);
        nftCollectionRules1155[1].purchaseAmount = 1e22;
        nftCollectionRules1155[1].purchaseAmountPerToken = false;
        nftCollectionRules1155[1].tokenIds = new uint256[](2);
        nftCollectionRules1155[1].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[1].tokenIds[0] = 1;
        nftCollectionRules1155[1].tokenIds[1] = 2;
        nftCollectionRules1155[1].minTokensEligible[0] = 1000;
        nftCollectionRules1155[1].minTokensEligible[1] = 2000;

        nftCollectionRulesPunks[0].collectionAddress = address(collectionAddress1);
        nftCollectionRulesPunks[0].purchaseAmount = 0;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = false;

        nftCollectionRulesPunks[1].collectionAddress = address(punks);
        nftCollectionRulesPunks[1].purchaseAmount = 1e22;
        nftCollectionRulesPunks[1].purchaseAmountPerToken = false;

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
            nftCollectionRules: nftCollectionRulesEmpty
        });

        IAelinPool.PoolData memory poolDataWith721;
        poolDataWith721 = IAelinPool.PoolData({
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

        IAelinPool.PoolData memory poolDataWith1155;
        poolDataWith1155 = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules1155
        });

        IAelinPool.PoolData memory poolDataWithPunks;
        poolDataWithPunks = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRulesPunks
        });

        poolAddress = poolFactory.createPool(poolData);
        poolAddressWith721 = poolFactory.createPool(poolDataWith721);
        poolAddressWith1155 = poolFactory.createPool(poolDataWith1155);
        poolAddressWithPunks = poolFactory.createPool(poolDataWithPunks);

        purchaseToken.approve(address(poolAddress), type(uint256).max);
        purchaseToken.approve(address(poolAddressWith721), type(uint256).max);
        purchaseToken.approve(address(poolAddressWith1155), type(uint256).max);
        purchaseToken.approve(address(poolAddressWithPunks), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          purchasePoolTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzzPurchasePoolTokens(uint256 purchaseTokenAmount, uint256 timestamp) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(timestamp < 20 days);
        assertTrue(!AelinPool(poolAddress).hasAllowList());

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        vm.warp(block.timestamp + timestamp);
        AelinPool(poolAddress).purchasePoolTokens(purchaseTokenAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseTokenAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseTokenAmount);
        if (purchaseTokenAmount == 1e27) assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + timestamp);
        assertEq(AelinPool(poolAddress).totalSupply(), AelinPool(poolAddress).balanceOf(address(this)));
    }

    function testFuzzMultiplePurchasePoolTokens(uint256 purchaseTokenAmount, uint256 numberOfTimes) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(numberOfTimes <= 1000);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));
        uint256 purchaseTokenTotal;

        for (uint256 i; i < numberOfTimes; ) {
            purchaseTokenTotal += purchaseTokenAmount;
            AelinPool(poolAddress).purchasePoolTokens(purchaseTokenAmount);

            assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseTokenTotal);
            assertEq(
                IERC20(purchaseToken).balanceOf(address(poolAddress)),
                balanceOfPoolBeforePurchase + purchaseTokenTotal
            );
            if (purchaseTokenAmount == 1e27) assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp);
            assertEq(AelinPool(poolAddress).totalSupply(), AelinPool(poolAddress).balanceOf(address(this)));

            unchecked {
                ++i;
            }
        }
    }

    function testRevertPurchasePoolMoreThanCap(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e35);
        vm.startPrank(address(0x1337));
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(poolAddress, type(uint256).max);

        vm.expectRevert("cap has been exceeded");
        AelinPool(poolAddress).purchasePoolTokens(purchaseAmount);
        vm.stopPrank();
    }

    function testFailPurchasePool721(uint256 purchaseTokenAmount, uint256 timestamp) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(timestamp < 20 days);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        vm.warp(block.timestamp + timestamp);
        AelinPool(poolAddressWith721).purchasePoolTokens(purchaseTokenAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseTokenAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith721)),
            balanceOfPoolBeforePurchase + purchaseTokenAmount
        );
        if (purchaseTokenAmount == 1e27)
            assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp + timestamp);
        assertEq(AelinPool(poolAddressWith721).totalSupply(), AelinPool(poolAddressWith721).balanceOf(address(this)));
    }

    function testFailPurchasePool1155(uint256 purchaseTokenAmount, uint256 timestamp) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(timestamp < 20 days);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));

        vm.warp(block.timestamp + timestamp);
        AelinPool(poolAddressWith1155).purchasePoolTokens(purchaseTokenAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseTokenAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseTokenAmount
        );
        if (purchaseTokenAmount == 1e27)
            assertEq(AelinPool(poolAddressWith1155).purchaseExpiry(), block.timestamp + timestamp);
        assertEq(AelinPool(poolAddressWith1155).totalSupply(), AelinPool(poolAddressWith1155).balanceOf(address(this)));
    }

    function testFailPurchasePoolPunks(uint256 purchaseTokenAmount, uint256 timestamp) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(timestamp < 20 days);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks));

        vm.warp(block.timestamp + timestamp);
        AelinPool(poolAddressWithPunks).purchasePoolTokens(purchaseTokenAmount);

        assertEq(AelinPool(poolAddressWithPunks).balanceOf(address(this)), purchaseTokenAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks)),
            balanceOfPoolBeforePurchase + purchaseTokenAmount
        );
        if (purchaseTokenAmount == 1e27)
            assertEq(AelinPool(poolAddressWithPunks).purchaseExpiry(), block.timestamp + timestamp);
        assertEq(AelinPool(poolAddressWithPunks).totalSupply(), AelinPool(poolAddressWithPunks).balanceOf(address(this)));
    }

    // TODO (testPurchasePoolTokensWithAllowList)

    /*//////////////////////////////////////////////////////////////
                         purchaseWithNFTs
    //////////////////////////////////////////////////////////////*/

    // 721 - scenario 1 - collectionAddress1
    // 721 - scenario 2 - collectionAddress2
    // 721 - scenario 3 - collectionAddress3
    // 1155 - collectionAddress4 & collectionAddress5
    // punks - punks

    /*//////////////////////////////////////////////////////////////
                            Scenario 1
    //////////////////////////////////////////////////////////////*/

    // scenario 1 - unlimited purchase with nft
    function testScenario1WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e35);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress1), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress1), 1));
        if (purchaseAmount == 1e35) assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp);
    }

    // scenario 1 - unlimited purchase from diff wallet - fail
    function testFailScenario1DiffWallet(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        vm.prank(address(0xBEEF));
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 1 - purchase with multiple nfts, same wallet
    function testScenario1Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e35);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);
        MockERC721(collectionAddress1).mint(address(this), 2);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress1), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress1), 1));
        if (purchaseAmount == 1e35) assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp);
    }

    // scenario 1 - purchase without the nft - fail
    function testFailScenario1WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount < type(uint256).max);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    function testFailPurchaseMoreThanCap721(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e35);
        vm.assume(purchaseAmount < type(uint256).max);

        MockERC721(collectionAddress1).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            Scenario 2
    //////////////////////////////////////////////////////////////*/

    // scenario 2 - purchase certain amount per wallet with nft
    function testScenario2WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress2), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress2), 1));
        assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp + 20 days);
    }

    // scenario 2 - purchase more amount than the cap per wallet with nft - fail
    function testFailScenario2Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e22);
        vm.assume(purchaseAmount < type(uint256).max);

        MockERC721(collectionAddress2).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 2 - purchase without nft - fail
    function testFailScenario2WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 2 - purchase multiple times with same nft - fail
    function testFailScenario2Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 5e21);
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress2).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 2 - purchase with diff wallet - fail
    function testFailScenario2DiffWallet(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress2).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        vm.prank(address(0xBEEF));
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            Scenario 3
    //////////////////////////////////////////////////////////////*/

    // scenario 3 - purchase limited amount per nft
    function testScenario3WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress3).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress3), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 1));
        assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp + 20 days);
    }

    // scenario 3 - purchase unlimited amount per nft per wallet - fail
    function testFailScenario3Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e22);
        vm.assume(purchaseAmount < type(uint256).max);

        MockERC721(collectionAddress3).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 3 - purchase multiple times with same nft - fail
    function testFailScenario3Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress3).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 3 - purchase without nft - fail
    function testFailScenario3WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // scenario 3 - purchase with more than 1 nft
    function testScenario3MultipleNfts(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 3e22);
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress3).mint(address(this), 1);
        MockERC721(collectionAddress3).mint(address(this), 2);
        MockERC721(collectionAddress3).mint(address(this), 3);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](3);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;
        nftPurchaseList[0].tokenIds[2] = 3;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress3), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 1));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 2));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 3));
        assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp + 20 days);
    }

    function testFailTransferNftAndPurchase1() public {
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);

        MockERC721(collectionAddress1).transferFrom(address(this), address(0xBEEF), 1);
        deal(address(purchaseToken), address(0xBEEF), 1e75);

        vm.prank(address(0xBEEF));
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
    }

    function testFailTransferNftAndPurchase2() public {
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress2).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);

        MockERC721(collectionAddress2).transferFrom(address(this), address(0xBEEF), 1);
        deal(address(purchaseToken), address(0xBEEF), 1e75);

        vm.prank(address(0xBEEF));
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
    }

    function testFailTransferNftAndPurchase3() public {
        assertTrue(AelinPool(poolAddressWith721).hasNftList());

        MockERC721(collectionAddress3).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress3);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);

        MockERC721(collectionAddress3).transferFrom(address(this), address(0xBEEF), 1);
        deal(address(purchaseToken), address(0xBEEF), 1e75);

        vm.prank(address(0xBEEF));
        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
    }

    /*//////////////////////////////////////////////////////////////
                                1155
    //////////////////////////////////////////////////////////////*/

    // 1155 - purchase with nfts
    function test1155WithNfts(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 2e22);
        assertTrue(AelinPool(poolAddressWith1155).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress4), 1));

        uint256[] memory mintIds = new uint256[](2);
        uint256[] memory mintAmount = new uint256[](2);

        mintIds[0] = 1;
        mintIds[1] = 2;
        mintAmount[0] = 100;
        mintAmount[1] = 200;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(collectionAddress4), address(this)));
    }

    // 1155 - purchase with another tokenId - fail
    function testFail1155AnotherTokenId(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddressWith1155).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress4), 1));

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 2;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // 1155 - purchase unlimted with tokenId when `purchaseAmountPerToken` is true - fail
    function testFail1155Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // 1155 - purchase multiple times with same tokenId - fail
    function testFail1155Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress5).batchMint(address(this), mintIds, mintAmount, "");

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    // 1155 - purchase unlimited when `purchaseAmountPerToken` is false and `purchaseAmount` > 0
    function test1155Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddressWith1155).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress5), 1));

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 2000;

        MockERC1155(collectionAddress5).batchMint(address(this), mintIds, mintAmount, "");

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress5);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(collectionAddress5), address(this)));
    }

    // combine both 1155 collections
    function test1155Combine(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 3e22);
        assertTrue(AelinPool(poolAddressWith1155).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress5), 1));
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress4), 1));

        uint256[] memory mintIds1 = new uint256[](2);
        uint256[] memory mintAmount1 = new uint256[](2);
        uint256[] memory mintIds2 = new uint256[](1);
        uint256[] memory mintAmount2 = new uint256[](1);

        mintIds1[0] = 1;
        mintIds1[1] = 2;
        mintAmount1[0] = 1000;
        mintAmount1[1] = 2000;
        mintIds2[0] = 1;
        mintAmount2[0] = 2000;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds1, mintAmount1, "");
        MockERC1155(collectionAddress5).batchMint(address(this), mintIds2, mintAmount2, "");

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;
        nftPurchaseList[1].collectionAddress = address(collectionAddress5);
        nftPurchaseList[1].tokenIds = new uint256[](1);
        nftPurchaseList[1].tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(!AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(collectionAddress4), address(this)));
        assertTrue(AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(collectionAddress5), address(this)));
    }

    // combine scenario 2 and 3 and purchase less than allocation
    function testScenario2and3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 3e22);

        MockERC721(collectionAddress2).mint(address(this), 1);
        MockERC721(collectionAddress2).mint(address(this), 2);
        MockERC721(collectionAddress3).mint(address(this), 1);
        MockERC721(collectionAddress3).mint(address(this), 2);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith721));

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;
        nftPurchaseList[1].collectionAddress = address(collectionAddress3);
        nftPurchaseList[1].tokenIds = new uint256[](2);
        nftPurchaseList[1].tokenIds[0] = 1;
        nftPurchaseList[1].tokenIds[1] = 2;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);

        assertEq(AelinPool(poolAddressWith721).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddressWith721)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - (purchaseAmount));

        assertTrue(AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress2), address(this)));
        assertTrue(!AelinPool(poolAddressWith721).nftWalletUsedForPurchase(address(collectionAddress3), address(this)));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress2), 1));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress2), 2));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 1));
        assertTrue(AelinPool(poolAddressWith721).nftId(address(collectionAddress3), 2));
    }

    // combine scenario 2 and 3 and purchase more than allocation - fail
    function testFailScenarios2and3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 3e22);
        vm.assume(purchaseAmount < 1e75);

        MockERC721(collectionAddress2).mint(address(this), 1);
        MockERC721(collectionAddress2).mint(address(this), 2);
        MockERC721(collectionAddress3).mint(address(this), 1);
        MockERC721(collectionAddress3).mint(address(this), 2);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;
        nftPurchaseList[1].collectionAddress = address(collectionAddress3);
        nftPurchaseList[1].tokenIds = new uint256[](2);
        nftPurchaseList[1].tokenIds[0] = 1;
        nftPurchaseList[1].tokenIds[1] = 2;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                Punks
    //////////////////////////////////////////////////////////////*/

    // punks - purchase with the tokenId
    function testPunksPurchasePool(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddressWithPunks).hasNftList());
        // owner of cryptopunks tokenId - 100
        address tokenOwner = address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 100;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks));
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 100;

        deal(address(purchaseToken), tokenOwner, 1e75);

        vm.startPrank(address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1));
        purchaseToken.approve(address(poolAddressWithPunks), type(uint256).max);
        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
        vm.stopPrank();

        assertEq(AelinPool(poolAddressWithPunks).balanceOf(tokenOwner), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(tokenOwner), 1e75 - purchaseAmount);
        assertTrue(AelinPool(poolAddressWithPunks).nftWalletUsedForPurchase(address(punks), tokenOwner));
        assertTrue(AelinPool(poolAddressWithPunks).nftId(address(punks), 100));
    }

    // punks - purchase without the tokenId - fail
    function testFailPunksPurchasePool() public {
        assertTrue(AelinPool(poolAddress).hasNftList());

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 100;

        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
    }

    // punks - purchase multiple times with same tokenId and diff wallet - fail
    function testFailPunksMultiple() public {
        assertTrue(AelinPool(poolAddress).hasNftList());
        // owner of cryptopunks tokenId - 100
        address tokenOwner = address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 100;

        deal(address(purchaseToken), tokenOwner, 1e75);

        vm.startPrank(address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1));
        purchaseToken.approve(address(poolAddressWithPunks), type(uint256).max);
        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
        vm.stopPrank();

        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(nftPurchaseList, 1e22);
    }

    function testFailAfterExpiry(uint256 purchaseAmount, uint256 timestamp) public {
        vm.assume(purchaseAmount < 1e35);
        vm.assume(timestamp > 20 days);
        vm.assume(timestamp < type(uint256).max);
        vm.warp(block.timestamp + timestamp);

        MockERC721(collectionAddress1).mint(address(this), 1);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        AelinPool(poolAddressWith721).purchasePoolTokensWithNft(nftPurchaseList, purchaseAmount);
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
