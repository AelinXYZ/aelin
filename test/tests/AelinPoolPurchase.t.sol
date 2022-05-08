// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICryptoPunks} from "contracts/interfaces/ICryptoPunks.sol";

contract AelinPoolPurchase is Test {
    address public aelinRewards = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
    address public poolAddress;
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
        poolFactory = new AelinPoolFactory(address(new AelinPool()), address(new AelinDeal()), aelinRewards);
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC721("TestCollection", "TC");
        collectionAddress4 = new MockERC1155("");
        collectionAddress5 = new MockERC1155("");

        deal(address(purchaseToken), address(this), 1e75);

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftData[] memory nftData = new IAelinPool.NftData[](3);
        IAelinPool.NftData[] memory nftDataWith1155 = new IAelinPool.NftData[](2);
        IAelinPool.NftData[] memory nftDataWithPunks = new IAelinPool.NftData[](2);

        nftData[0].collectionAddress = address(collectionAddress1);
        nftData[0].purchaseAmount = 0;
        nftData[0].purchaseAmountPerToken = false;

        nftData[1].collectionAddress = address(collectionAddress2);
        nftData[1].purchaseAmount = 1e22;
        nftData[1].purchaseAmountPerToken = false;

        nftData[2].collectionAddress = address(collectionAddress3);
        nftData[2].purchaseAmount = 1e22;
        nftData[2].purchaseAmountPerToken = true;

        nftDataWith1155[0].collectionAddress = address(collectionAddress4);
        nftDataWith1155[0].purchaseAmount = 1e22;
        nftDataWith1155[0].purchaseAmountPerToken = true;
        nftDataWith1155[0].minTokensEligible = 100;
        nftDataWith1155[0].tokenIds = new uint256[](2);
        nftDataWith1155[0].tokenIds[0] = 1;
        nftDataWith1155[0].tokenIds[1] = 2;

        nftDataWith1155[1].collectionAddress = address(collectionAddress5);
        nftDataWith1155[1].purchaseAmount = 0;
        nftDataWith1155[1].purchaseAmountPerToken = false;
        nftDataWith1155[1].minTokensEligible = 100;
        nftDataWith1155[1].tokenIds = new uint256[](2);
        nftDataWith1155[1].tokenIds[0] = 1;
        nftDataWith1155[1].tokenIds[1] = 2;

        nftDataWithPunks[0].collectionAddress = address(collectionAddress1);
        nftDataWithPunks[0].purchaseAmount = 0;
        nftDataWithPunks[0].purchaseAmountPerToken = false;

        nftDataWithPunks[1].collectionAddress = address(punks);
        nftDataWithPunks[1].purchaseAmount = 1e22;
        nftDataWithPunks[1].purchaseAmountPerToken = false;

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
            nftData: nftData
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
            nftData: nftDataWith1155
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
            nftData: nftDataWithPunks
        });

        poolAddress = poolFactory.createPool(poolData);
        poolAddressWith1155 = poolFactory.createPool(poolDataWith1155);
        poolAddressWithPunks = poolFactory.createPool(poolDataWithPunks);

        purchaseToken.approve(address(poolAddress), type(uint256).max);
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

    // scenario 1 - unlimited purchase per wallet with nft
    function testScenario1WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e75);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), 0);
        assertTrue(AelinPool(poolAddress).nftWalletUsedForPurchase(address(this)));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress1), 1));
    }

    // scenario 1 - unlimited purchase from diff wallet - fail
    function testFailScenario1DiffWallet(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(address(0xBEEF));
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    // scenario 1 - multiple times purchase with same wallet - fail
    function testFailScenario1Multiple(uint256 purchaseAmount) public {
        // 1e22 / 2 = 5e21
        vm.assume(purchaseAmount >= 5e21);
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, purchaseAmount);
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    // scenario 1 - purchase without the nft - fail
    function testFailScenario1WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            Scenario 2
    //////////////////////////////////////////////////////////////*/

    // scenario 2 - purchase certain amount per wallet with nft
    function testScenario2WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), purchaseAmount);
        assertTrue(AelinPool(poolAddress).nftWalletUsedForPurchase(address(this)));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress2), 1));
    }

    // scenario 2 - purchase more amount than the cap per wallet with nft - fail
    function testFailScenario2Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);
        vm.assume(purchaseAmount < type(uint256).max);

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);
    }

    // scenario 2 - purchase without nft - fail
    function testFailScenario2WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);
    }

    // scenario 2 - purchase multiple times with nft - fail
    function testFailScenario2Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 5e21);
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);
    }

    // scenario 2 - purchase with diff wallet - fail
    function testFailScenario2DiffWallet(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(address(0xBEEF));
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress2), tokenIds, purchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            Scenario 3
    //////////////////////////////////////////////////////////////*/

    // scenario 3 - purchase limited amount per nft per wallet
    function testScenario3WithNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress3).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), 0);
        assertTrue(AelinPool(poolAddress).nftWalletUsedForPurchase(address(this)));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress3), 1));
    }

    // scenario 3 - purchase unlimited amount per nft per wallet - fail
    function testFailScenario3Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e22);
        vm.assume(purchaseAmount < type(uint256).max);

        MockERC721(collectionAddress3).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);
    }

    // scenario 3 - purchase multiple times with same nft - fail
    function testFailScenario3Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        MockERC721(collectionAddress3).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);
    }

    // scenario 3 - purchase without nft - fail
    function testFailScenario3WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);
    }

    // scenario 3 - purchase with more than 1 nft
    function testScenario3MultipleNfts(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 3e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress3).mint(address(this), 1);
        MockERC721(collectionAddress3).mint(address(this), 2);
        MockERC721(collectionAddress3).mint(address(this), 3);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - (purchaseAmount));
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), 0);
        assertTrue(AelinPool(poolAddress).nftWalletUsedForPurchase(address(this)));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress3), 1));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress3), 2));
        assertTrue(AelinPool(poolAddress).nftId(address(collectionAddress3), 3));
    }

    function testFailTransferNftAndPurchase() public {
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, 1e22);

        MockERC721(collectionAddress1).transferFrom(address(this), address(0xBEEF), 1);
        deal(address(purchaseToken), address(0xBEEF), 1e75);

        vm.prank(address(0xBEEF));
        AelinPool(poolAddress).purchasePoolTokensWithNft(address(collectionAddress1), tokenIds, 1e22);
    }

    /*//////////////////////////////////////////////////////////////
                                1155
    //////////////////////////////////////////////////////////////*/

    // 1155 - purchase with nfts
    function test1155WithNfts(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 2e22);
        assertTrue(AelinPool(poolAddress).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress4), 1));

        uint256[] memory mintIds = new uint256[](2);
        uint256[] memory mintAmount = new uint256[](2);

        mintIds[0] = 1;
        mintIds[1] = 2;
        mintAmount[0] = 100;
        mintAmount[1] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress4), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddressWith1155).nftAllowList(address(this)), 0);
        assertTrue(AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(this)));
    }

    // 1155 - purchase with another tokenId - fail
    function testFail1155AnotherTokenId(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 2;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress4), tokenIds, purchaseAmount);
    }

    // 1155 - purchase unlimted with tokenId when `purchaseAmountPerToken` is true - fail
    function testFail1155Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 2;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress4), tokenIds, purchaseAmount);
    }

    // 1155 - purchase multiple times with same tokenId - fail
    function testFail1155Multiple(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress4), tokenIds, purchaseAmount);
        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress4), tokenIds, purchaseAmount);
    }

    // 1155 - purchase unlimited when `purchaseAmountPerToken` is false and `purchaseAmount` is 0
    function test1155Unlimited(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount >= 1e22);
        vm.assume(purchaseAmount <= 1e75);
        assertTrue(AelinPool(poolAddress).hasNftList());
        assertTrue(AelinPool(poolAddressWith1155).nftId(address(collectionAddress5), 1));

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress5).batchMint(address(this), mintIds, mintAmount, "");

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWith1155));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress5), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddressWith1155).balanceOf(address(this)), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWith1155)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddressWith1155).nftAllowList(address(this)), 0);
        assertTrue(AelinPool(poolAddressWith1155).nftWalletUsedForPurchase(address(this)));
    }

    function testFailMultiplePurchasePoolWith1155() public {
        assertTrue(AelinPool(poolAddress).hasNftList());

        uint256[] memory mintIds = new uint256[](1);
        uint256[] memory mintAmount = new uint256[](1);

        mintIds[0] = 1;
        mintAmount[0] = 100;

        MockERC1155(collectionAddress4).batchMint(address(this), mintIds, mintAmount, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, 5e21);
        AelinPool(poolAddressWith1155).purchasePoolTokensWithNft(address(collectionAddress3), tokenIds, 5e21);
    }

    /*//////////////////////////////////////////////////////////////
                                Punks
    //////////////////////////////////////////////////////////////*/

    // punks - purchase with the tokenId
    function testPunksPurchasePool(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());
        // owner of cryptopunks tokenId - 100
        address tokenOwner = address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 100;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks));

        deal(address(purchaseToken), tokenOwner, 1e75);

        vm.startPrank(address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1));
        purchaseToken.approve(address(poolAddressWithPunks), type(uint256).max);
        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(address(punks), tokenIds, purchaseAmount);
        vm.stopPrank();

        assertEq(AelinPool(poolAddressWithPunks).balanceOf(tokenOwner), purchaseAmount);
        assertEq(
            IERC20(purchaseToken).balanceOf(address(poolAddressWithPunks)),
            balanceOfPoolBeforePurchase + purchaseAmount
        );
        assertEq(IERC20(purchaseToken).balanceOf(tokenOwner), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddressWithPunks).nftAllowList(tokenOwner), purchaseAmount);
        assertTrue(AelinPool(poolAddressWithPunks).nftWalletUsedForPurchase(tokenOwner));
        assertTrue(AelinPool(poolAddressWithPunks).nftId(address(punks), 100));
    }

    // punks - purchase without the tokenId - fail
    function testFailPunksPurchasePool() public {
        assertTrue(AelinPool(poolAddress).hasNftList());

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 100;

        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(address(punks), tokenIds, 1e22);
    }

    // punks - purchase multiple times with the tokenId - fail
    function testFailPunksMultiple() public {
        assertTrue(AelinPool(poolAddress).hasNftList());
        // owner of cryptopunks tokenId - 100
        address tokenOwner = address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 100;

        deal(address(purchaseToken), tokenOwner, 1e75);

        vm.startPrank(address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1));
        purchaseToken.approve(address(poolAddressWithPunks), type(uint256).max);
        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(address(punks), tokenIds, 1e22);
        vm.stopPrank();

        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(address(punks), tokenIds, 1e22);
        AelinPool(poolAddressWithPunks).purchasePoolTokensWithNft(address(punks), tokenIds, 1e22);
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
