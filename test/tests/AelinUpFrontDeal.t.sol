// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
import "../../contracts/libraries/MerkleTree.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC20CustomDecimals} from "../mocks/MockERC20CustomDecimals.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockPunks} from "../mocks/MockPunks.sol";

contract AelinUpFrontDealTest is Test {
    using SafeERC20 for IERC20;

    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;

    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    AelinUpFrontDeal public testUpFrontDeal;
    AelinUpFrontDealFactory public upFrontDealFactory;
    AelinFeeEscrow public testEscrow;
    MockERC20 public purchaseToken;
    MockERC20 public underlyingDealToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;
    MockERC721 public collectionAddress3;
    MockERC1155 public collectionAddress4;
    MockERC1155 public collectionAddress5;
    MockPunks public collectionAddressPunks;

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;
    IAelinUpFrontDeal.UpFrontDealConfig public sharedDealConfig;
    MerkleTree.UpFrontMerkleData public merkleDataEmpty;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);
    address user2 = address(0x1338);
    address user3 = address(0x1339);

    address dealAddress;
    address dealAddressAllowDeallocation;
    address dealAddressOverFullDeposit;
    address dealAddressAllowList;
    address dealAddressNftGating721;
    address dealAddressNftGatingPunks;
    address dealAddressNftGating1155;

    function setUp() public {
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);
        purchaseToken = new MockERC20("MockPurchase", "MP");
        underlyingDealToken = new MockERC20("MockDeal", "MD");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC721("TestCollection", "TC");
        collectionAddress4 = new MockERC1155("");
        collectionAddress5 = new MockERC1155("");
        collectionAddressPunks = new MockPunks();

        vm.startPrank(dealCreatorAddress);
        deal(address(this), type(uint256).max);
        deal(address(underlyingDealToken), address(dealCreatorAddress), type(uint256).max);
        underlyingDealToken.approve(address(upFrontDealFactory), type(uint256).max);

        assertEq(upFrontDealFactory.UP_FRONT_DEAL_LOGIC(), address(testUpFrontDeal));
        assertEq(upFrontDealFactory.AELIN_ESCROW_LOGIC(), address(testEscrow));
        assertEq(upFrontDealFactory.AELIN_TREASURY(), address(aelinTreasury));

        AelinAllowList.InitData memory allowListInitEmpty;
        AelinAllowList.InitData memory allowListInit;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        allowListInit.allowListAddresses = testAllowListAddresses;
        allowListInit.allowListAmounts = testAllowListAmounts;

        // NFT Gating

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = getPunksCollection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        // Deal initialization
        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10 ** 18,
            ipfsHash: "",
            merkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1e35,
            purchaseTokenPerDealToken: 3e18,
            purchaseRaiseMinimum: 1e28,
            purchaseDuration: 10 days,
            vestingPeriod: 365 days,
            vestingCliffPeriod: 60 days,
            allowDeallocation: false
        });
        sharedDealConfig = dealConfig;

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfigAllowDeallocation;
        dealConfigAllowDeallocation = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1e35,
            purchaseTokenPerDealToken: 3e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 10 days,
            vestingPeriod: 365 days,
            vestingCliffPeriod: 60 days,
            allowDeallocation: true
        });

        dealAddress = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        dealAddressAllowDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        dealAddressOverFullDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        dealAddressAllowList = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInit
        );

        dealAddressNftGating721 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721,
            allowListInitEmpty
        );

        dealAddressNftGatingPunks = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesPunks,
            allowListInitEmpty
        );

        dealAddressNftGating1155 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules1155,
            allowListInitEmpty
        );

        vm.stopPrank();
        vm.startPrank(address(0xDEAD));

        // Deposit underlying tokens to save time for next tests
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowList), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowList).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressOverFullDeposit).depositUnderlyingTokens(1e36);

        underlyingDealToken.approve(address(dealAddressNftGating721), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGatingPunks), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGatingPunks).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating1155).depositUnderlyingTokens(1e35);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            helper functions
    //////////////////////////////////////////////////////////////*/

    function getDealData() public view returns (IAelinUpFrontDeal.UpFrontDealData memory) {
        return
            IAelinUpFrontDeal.UpFrontDealData({
                name: "DEAL",
                symbol: "DEAL",
                purchaseToken: address(purchaseToken),
                underlyingDealToken: address(underlyingDealToken),
                holder: address(0xDEAD),
                sponsor: address(0xBEEF),
                sponsorFee: 1 * 10 ** 18,
                ipfsHash: "",
                merkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            });
    }

    function getDealConfig() public pure returns (IAelinUpFrontDeal.UpFrontDealConfig memory) {
        return
            IAelinUpFrontDeal.UpFrontDealConfig({
                underlyingDealTokenTotal: 1e35,
                purchaseTokenPerDealToken: 3e18,
                purchaseRaiseMinimum: 1e28,
                purchaseDuration: 10 days,
                vestingPeriod: 365 days,
                vestingCliffPeriod: 60 days,
                allowDeallocation: false
            });
    }

    function getAllowList() public pure returns (AelinAllowList.InitData memory) {
        AelinAllowList.InitData memory allowList;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        allowList.allowListAddresses = testAllowListAddresses;
        allowList.allowListAmounts = testAllowListAmounts;
        return allowList;
    }

    function getERC721Collection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules721[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules721[0].purchaseAmount = 1e20;
        nftCollectionRules721[0].purchaseAmountPerToken = true;
        nftCollectionRules721[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules721[1].purchaseAmount = 1e22;
        nftCollectionRules721[1].purchaseAmountPerToken = false;

        return nftCollectionRules721;
    }

    function getERC1155Collection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules1155[0].collectionAddress = address(collectionAddress4);
        nftCollectionRules1155[0].purchaseAmount = 1e20;
        nftCollectionRules1155[0].purchaseAmountPerToken = true;
        nftCollectionRules1155[0].tokenIds = new uint256[](2);
        nftCollectionRules1155[0].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[0].tokenIds[0] = 1;
        nftCollectionRules1155[0].tokenIds[1] = 2;
        nftCollectionRules1155[0].minTokensEligible[0] = 10;
        nftCollectionRules1155[0].minTokensEligible[1] = 20;
        nftCollectionRules1155[1].collectionAddress = address(collectionAddress5);
        nftCollectionRules1155[1].purchaseAmount = 1e22;
        nftCollectionRules1155[1].purchaseAmountPerToken = false;
        nftCollectionRules1155[1].tokenIds = new uint256[](2);
        nftCollectionRules1155[1].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[1].tokenIds[0] = 10;
        nftCollectionRules1155[1].tokenIds[1] = 20;
        nftCollectionRules1155[1].minTokensEligible[0] = 1000;
        nftCollectionRules1155[1].minTokensEligible[1] = 2000;

        return nftCollectionRules1155;
    }

    function getPunksCollection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRulesPunks[0].collectionAddress = address(punks);
        nftCollectionRulesPunks[0].purchaseAmount = 1e22;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = false;

        return nftCollectionRulesPunks;
    }

    /*//////////////////////////////////////////////////////////////
                            initialize()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertInitializeCannotCallInitializeTwice() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        vm.expectRevert("can only init once");
        AelinUpFrontDeal(dealAddress).initialize(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty,
            aelinTreasury,
            address(testEscrow)
        );

        vm.stopPrank();
    }

    function testRevertInitializeCannotUseNullOrSameToken() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.underlyingDealToken = address(purchaseToken);

        vm.expectRevert("purchase & underlying the same");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealData.purchaseToken = address(0);
        vm.expectRevert("cant pass null purchase address");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealData.purchaseToken = address(purchaseToken);
        dealData.underlyingDealToken = address(0);
        vm.expectRevert("cant pass null underlying address");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeCannotUseNullHolder() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.holder = address(0);

        vm.expectRevert("cant pass null holder address");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeWrongSponsorFee(uint256 _sponsorFee) public {
        vm.startPrank(dealCreatorAddress);
        vm.assume(_sponsorFee > MAX_SPONSOR_FEE);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.sponsorFee = _sponsorFee;

        vm.expectRevert("exceeds max sponsor fee");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeWrongDurations(
        uint256 _purchaseDuration,
        uint256 _vestingCliffPeriod,
        uint256 _vestingPeriod
    ) public {
        vm.startPrank(dealCreatorAddress);
        vm.assume(_purchaseDuration > 30 days);
        vm.assume(_vestingCliffPeriod > 1825 days);
        vm.assume(_vestingPeriod > 1825 days);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealConfig.purchaseDuration = _purchaseDuration;

        vm.expectRevert("not within limit");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.purchaseDuration = 1 minutes;
        vm.expectRevert("not within limit");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.purchaseDuration = 10 days;
        dealConfig.vestingCliffPeriod = _vestingCliffPeriod;
        dealConfig.vestingPeriod = _vestingPeriod;
        vm.expectRevert("max 5 year cliff");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.vestingCliffPeriod = 365 days;
        vm.expectRevert("max 5 year vesting");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializePurchaseTokenNotCompatible() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.purchaseToken = address(new MockERC20CustomDecimals("MockERC20", "ME", 20));
        vm.expectRevert("purchase token not compatible");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeWrongDealSetup() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealConfig.underlyingDealTokenTotal = 0;
        vm.expectRevert("must have nonzero deal tokens");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.underlyingDealTokenTotal = 100;
        dealConfig.purchaseTokenPerDealToken = 0;
        vm.expectRevert("invalid deal price");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.purchaseTokenPerDealToken = 1;
        dealConfig.underlyingDealTokenTotal = 1;
        vm.expectRevert("intended raise too small");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        dealConfig.underlyingDealTokenTotal = 1e28;
        vm.expectRevert("raise min > deal total");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeCannotUseAllowListAndNFT() public {
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("cant have allow list & nft");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), getERC721Collection(), getAllowList());
        vm.stopPrank();
    }

    function testRevertInitializeCannotUse721And1155() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](4);

        nftCollectionRules[0] = nftCollectionRules721[0];
        nftCollectionRules[1] = nftCollectionRules721[1];
        nftCollectionRules[2] = nftCollectionRules1155[0];
        nftCollectionRules[3] = nftCollectionRules1155[1];

        vm.expectRevert("can only contain 721");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListInitEmpty);

        nftCollectionRules[0] = nftCollectionRules1155[0];
        nftCollectionRules[1] = nftCollectionRules1155[1];
        nftCollectionRules[2] = nftCollectionRules721[0];
        nftCollectionRules[3] = nftCollectionRules721[1];

        vm.expectRevert("can only contain 1155");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeCannotUsePunksAnd1155() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = getPunksCollection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](3);

        nftCollectionRules[0] = nftCollectionRulesPunks[0];
        nftCollectionRules[1] = nftCollectionRules1155[0];
        nftCollectionRules[2] = nftCollectionRules1155[1];

        vm.expectRevert("can only contain 721");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListInitEmpty);

        nftCollectionRules[0] = nftCollectionRules1155[0];
        nftCollectionRules[1] = nftCollectionRules1155[1];
        nftCollectionRules[2] = nftCollectionRulesPunks[0];

        vm.expectRevert("can only contain 1155");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListInitEmpty);

        vm.stopPrank();
    }

    function testRevertInitializeCannotUseAnotherERCType() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListInitEmpty;
        MockERC20 token = new MockERC20("MockToken", "MT");
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRules[0].collectionAddress = address(token);
        nftCollectionRules[0].purchaseAmount = 1e20;
        nftCollectionRules[0].purchaseAmountPerToken = true;

        vm.expectRevert("collection is not compatible");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListInitEmpty);

        vm.stopPrank();
    }

    // Pass scenarios

    function testInitializeNoDeallocation() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddress)), 0);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying hasn't been deposited yet so deal has't started
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertFalse(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressOverFullDeposit).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressOverFullDeposit).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeAllowDeallocation() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressAllowDeallocation)), 0);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying hasn't been deposited yet so deal has't started
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 0);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertTrue(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeOverFullDeposit() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressOverFullDeposit)), 1e36);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        assertFalse(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressOverFullDeposit).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressOverFullDeposit).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeAllowList() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressAllowList)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressAllowList).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressAllowList).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowList).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowList).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // test allow list
        address[] memory tempAddressArray;
        uint256[] memory tempUintArray;
        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        (tempAddressArray, tempUintArray, , tempBool) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(address(0));
        assertTrue(tempBool);
        assertEq(testAllowListAddresses.length, tempAddressArray.length);
        assertEq(tempAddressArray[0], address(0x1337));
        assertEq(tempAddressArray[1], address(0xBEEF));
        assertEq(tempAddressArray[2], address(0xDEED));
        assertEq(tempUintArray[0], 1e18);
        assertEq(tempUintArray[1], 2e18);
        assertEq(tempUintArray[2], 3e18);
        for (uint256 i; i < tempAddressArray.length; ) {
            (, , tempUint, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(tempAddressArray[i]);
            assertEq(tempUint, testAllowListAmounts[i]);
            unchecked {
                ++i;
            }
        }
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressAllowList).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeNftGating721() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNftGating721)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGating721).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, , tempBool) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress1));
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collectionAddress2));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collectionAddress2));
        assertFalse(tempBool);
    }

    function testInitializeNftGatingPunks() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNftGatingPunks)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGatingPunks).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, , tempBool) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGatingPunks)
            .getNftCollectionDetails(address(punks));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(punks));
        assertFalse(tempBool);
    }

    function testInitializeNftGating1155() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNftGating1155)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGating1155).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, , tempBool) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collectionAddress4));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress4));
        assertTrue(tempBool);
        assertEq(tempUintArray1[0], 1);
        assertEq(tempUintArray1[1], 2);
        assertEq(tempUintArray2[0], 10);
        assertEq(tempUintArray2[1], 20);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collectionAddress5));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collectionAddress5));
        assertFalse(tempBool);
        assertEq(tempUintArray1[0], 10);
        assertEq(tempUintArray1[1], 20);
        assertEq(tempUintArray2[0], 1000);
        assertEq(tempUintArray2[1], 2000);
    }

    //     /*//////////////////////////////////////////////////////////////
    //                         pre depositUnderlyingTokens()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertCannotAcceptDealBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, 1e18);
        vm.stopPrank();
    }

    function testRevertPurchaserCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).purchaserClaim();
        vm.stopPrank();
    }

    function testRevertSponsorCannotClaimBeforeDeposit() public {
        vm.prank(dealCreatorAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertHolderCannotClaimBeforeDeposit() public {
        vm.prank(dealHolderAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).holderClaim();
        vm.stopPrank();
    }

    function testRevertTreasuryCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).feeEscrowClaim();
        vm.stopPrank();
    }

    function testRevertCannotClaimUnderlyingBeforeDeposit(address _testAddress, uint256 _tokenId) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).claimUnderlying(_tokenId);
        vm.stopPrank();
    }

    // Pass scenarios

    function testClaimableBeforeDeposit(address _testAddress, uint256 _tokenId) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        assertEq(AelinUpFrontDeal(dealAddress).claimableUnderlyingTokens(_tokenId), 0);
        vm.stopPrank();
    }

    //     /*//////////////////////////////////////////////////////////////
    //                         depositUnderlyingTokens()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanDepositUnderlying(address _testAddress, uint256 _depositAmount) public {
        vm.assume(_testAddress != dealHolderAddress);
        vm.prank(_testAddress);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testRevertDepositUnderlyingNotEnoughBalance(uint256 _depositAmount, uint256 _holderBalance) public {
        vm.assume(_holderBalance < _depositAmount);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, _holderBalance);
        underlyingDealToken.approve(address(dealAddress), _holderBalance);
        vm.expectRevert("not enough balance");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testRevertDepositUnderlyingAfterComplete(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressOverFullDeposit).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    // Pass scenarios

    function testPartialThenFullDepositUnderlying(uint256 _firstDepositAmount, uint256 _secondDepositAmount) public {
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);

        // first deposit
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        (bool success, uint256 result) = SafeMath.tryAdd(_firstDepositAmount, _secondDepositAmount);
        vm.assume(success);
        vm.assume(result >= underlyingDealTokenTotal);
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(dealAddress);
        vm.assume(_firstDepositAmount < underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _firstDepositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_firstDepositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddress);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _firstDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);

        // second deposit
        balanceBeforeDeposit = balanceAfterDeposit;
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _secondDepositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_secondDepositAmount);
        balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddress);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _secondDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);

        vm.stopPrank();
    }

    function testDepositUnderlyingFullDeposit(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);

        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddress));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);

        // deposit initiated
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _depositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(address(dealAddress));
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _depositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);

        // should revert when trying to deposit again
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);

        vm.stopPrank();
    }

    function testDirectUnderlyingDeposit(address _depositor, uint256 _depositAmount) public {
        vm.assume(_depositor != dealHolderAddress);
        vm.assume(_depositor != address(0));
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddress));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.startPrank(_depositor);

        // random wallet sends the funds
        deal(address(underlyingDealToken), _depositor, type(uint256).max);
        underlyingDealToken.transfer(dealAddress, _depositAmount);
        assertEq(underlyingDealToken.balanceOf(address(dealAddress)), _depositAmount + balanceBeforeDeposit);
        assertGe(underlyingDealToken.balanceOf(address(dealAddress)), underlyingDealTokenTotal);

        // deposit is still not complete
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);

        // depositUnderlyingTokens() still needs to be called
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, 0);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(0);

        // deposit is now flagged as completed
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            setHolder() / acceptHolder()
        //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanSetNewHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(_futureHolder);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(holderAddress, dealHolderAddress);
        vm.stopPrank();
    }

    function testRevertOnlyDesignatedHolderCanAccept(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(dealHolderAddress);

        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddress).futureHolder(), _futureHolder);
        vm.expectRevert("only future holder can access");
        AelinUpFrontDeal(dealAddress).acceptHolder();
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(holderAddress, dealHolderAddress);

        vm.stopPrank();
    }

    // Pass scenarios

    function testSetAndAcceptHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(dealHolderAddress);
        address temHolderAddress;

        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddress).futureHolder(), _futureHolder);
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(temHolderAddress, dealHolderAddress);
        vm.stopPrank();

        vm.startPrank(_futureHolder);
        vm.expectEmit(false, false, false, false);
        emit SetHolder(_futureHolder);
        AelinUpFrontDeal(dealAddress).acceptHolder();
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(temHolderAddress, _futureHolder);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  vouch()
        //////////////////////////////////////////////////////////////*/

    function testFuzzVouchForDeal(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Vouch(_attestant);
        AelinUpFrontDeal(dealAddress).vouch();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  disavow()
        //////////////////////////////////////////////////////////////*/

    function testFuzzDisavowForDeal(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Disavow(_attestant);
        AelinUpFrontDeal(dealAddress).disavow();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                withdrawExcess()
        //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertOnlyHolderCanWithdrawExcess(address _initiator) public {
        vm.assume(_initiator != dealHolderAddress);
        vm.startPrank(_initiator);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddress).withdrawExcess();
        vm.stopPrank();
    }

    function testRevertNoExcessToWithdraw(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        vm.assume(_depositAmount <= underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        vm.expectRevert("no excess to withdraw");
        AelinUpFrontDeal(dealAddress).withdrawExcess();
        vm.stopPrank();
    }

    // Pass scenarios

    function testWithdrawExcess(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        vm.assume(_depositAmount > underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterTransfer = underlyingDealToken.balanceOf(dealAddress);
        uint256 expectedWithdraw = balanceAfterTransfer - underlyingDealTokenTotal;
        vm.expectEmit(false, false, false, false);
        emit WithdrewExcess(address(dealAddress), expectedWithdraw);
        AelinUpFrontDeal(dealAddress).withdrawExcess();
        assertEq(underlyingDealToken.balanceOf(dealAddress), underlyingDealTokenTotal);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  acceptDeal()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertAcceptDealBeforeDepositComplete(address _user, uint256 _purchaseAmount) public {
        vm.prank(_user);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        // deposit to start purchase period
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(underlyingDealTokenTotal);
        vm.stopPrank();

        // warp past purchase period and try to accept deal
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddress).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.startPrank(_user);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);

        // try on a contract that was deposited during intialize
        purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotEnoughTokens() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint256 tokenAmount = 100;
        vm.prank(user1);
        deal(address(purchaseToken), user1, tokenAmount);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectRevert("not enough purchaseToken");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, tokenAmount + 1);
        vm.stopPrank();
    }

    function testRevertAcceptDealOverAllowListAllocation(uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        (, , uint256 allocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user1);
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, allocatedAmount + 1);
        vm.stopPrank();
    }

    function testRevertPurchaseAmountTooSmall(uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        (, , uint256 allocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user1);
        vm.expectRevert("purchase amount too small");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, 0);
        vm.stopPrank();
    }

    function testRevertAcceptDealOverTotal() public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();

        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;

        // User 1 tries to deposit more than the total purchase amount
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);

        uint256 expectedPoolShareAmount = ((raiseAmount + 1e18) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        assertGt(expectedPoolShareAmount, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, raiseAmount + 1e18);

        // User 1 now deposits less than the total purchase amount
        uint256 purchaseAmount1 = raiseAmount - 2e18;
        expectedPoolShareAmount = (purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount1, purchaseAmount1, expectedPoolShareAmount, expectedPoolShareAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);
        vm.stopPrank();

        // User 2 now deposits more than the total purchase amount
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        uint256 purchaseAmount2 = purchaseAmount1 + 3e18;
        uint256 totalPoolShares = ((purchaseAmount2 + purchaseAmount1) * 10 ** underlyingTokenDecimals) /
            purchaseTokenPerDealToken;
        assertGt(totalPoolShares, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotInAllowList(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNoNftList(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("pool does not have an NFT list");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNoNftPurchaseList(uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("must provide purchase list");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNftCollectionNotSupported(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = punks;
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("collection not in the pool");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC720MustBeOwner(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collectionAddress1).mint(user2, 1);
        MockERC721(collectionAddress1).mint(user2, 2);
        vm.expectRevert("has to be the token owner");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealPunksMustBeOwner(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunks), type(uint256).max);

        // Since punks address is hardcoded we need to cheat and link the Mock contract to the address
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // We mint some punks to another user
        MockPunks(punks).mint(user2, 1);
        MockPunks(punks).mint(user2, 2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        // We mint the tokens to another user
        vm.expectRevert("not the owner");
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC1155BalanceTooLow(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC1155(collectionAddress4).mint(user2, 1, 1, "");
        MockERC1155(collectionAddress4).mint(user2, 2, 1, "");
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC721AlreadyUsed(uint256 _purchaseAmount) public {}

    function testRevertAcceptDealERC721WalletAlreadyUsed(uint256 _purchaseAmount) public {}

    function testRevertAcceptDealERC721OverAllowed(uint256 _purchaseAmount) public {}

    // Pass scenarios

    function testAcceptDealBasic(uint256 _purchaseAmount) public {}

    function testAcceptDealMultiplePurchasers() public {}

    function testAcceptDealAllowDeallocation() public {}

    function testAcceptDealAllowList(uint256 _purchaseAmount1, uint256 _purchaseAmount2, uint256 _purchaseAmount3) public {}

    function testAcceptDealERC721(uint256 _purchaseAmount) public {}

    function testAcceptDealPunks() public {}

    function testAcceptDealERC1155(uint256 _purchaseAmount) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                             purchaserClaim()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertPurchaserClaimNotInWindow() public {}

    //     function testRevertPurchaserClaimNoShares(address _user) public {}

    //     // Pass scenarios

    //     // Does not meet purchaseRaiseMinimum
    //     function testPurchaserClaimRefund(uint256 _purchaseAmount) public {}

    //     function testPurchaserClaimNoDeallocation(uint256 _purchaseAmount) public {}

    //     function testPurchaserClaimWithDeallocation() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                             sponsorClaim()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertSponsorClaimNotInWindow() public {}

    //     function testRevertSponsorClaimFailMinimumRaise(uint256 _purchaseAmount) public {}

    //     function testRevertSponsorClaimNotSponsor(uint256 _purchaseAmount, address _address) public {}

    //     function testRevertSponsorClaimAlreadyClaimed() public {}

    //     // Pass scenarios

    //     function testSponsorClaimNoDeallocation(uint256 _purchaseAmount) public {}

    //     function testSponsorClaimWithDeallocation() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                             holderClaim()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertHolderClaimNotInWindow() public {}

    //     function testRevertHolderClaimNotHolder(address _address, uint256 _purchaseAmount) public {}

    //     function testRevertHolderClaimAlreadyClaimed() public {}

    //     function testRevertHolderClaimFailMinimumRaise(uint256 _purchaseAmount) public {}

    //     // Pass scenarios

    //     function testHolderClaimNoDeallocation() public {}

    //     function testHolderClaimWithDeallocation() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                             feeEscrowClaim()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertEscrowClaimNotInWindow() public {}

    //     // Pass scenarios

    //     function testEscrowClaimNoDeallocation(address _address) public {}

    //     function testEscrowClaimWithDeallocation(address _address) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         claimableUnderlyingTokens()
    //     //////////////////////////////////////////////////////////////*/

    //     function testClaimableUnderlyingNotInWindow(uint256 _tokenId) public {}

    //     function testClaimableUnderlyingWithWrongTokenId(uint256 _purchaseAmount) public {}

    //     function testClaimableUnderlyingQuantityZero(address _address) public {}

    //     function testClaimableUnderlyingDuringVestingCliff(uint256 _timeAfterPurchasing) public {}

    //     function testClaimableUnderlyingAfterVestingEnd(uint256 _timeAfterPurchasing) public {}

    //     function testClaimableUnderlyingDuringVestingPeriod(uint256 _timeAfterPurchasing) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         claimUnderlying()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertClaimUnderlyingNotInWindow(uint256 _tokenId) public {}

    //     function testRevertClaimUnderlyingFailMinimumRaise(uint256 _purchaseAmount, uint256 _tokenId) public {}

    //     function testRevertClaimUnderlyingQuantityZero(address _address, uint256 _timeAfterPurchasing) public {}

    //     function testRevertClaimUnderlyingNotOwner(uint256 _purchaseAmount) public {}

    //     function testRevertClaimUnderlyingIncorrectTokenId(uint256 _purchaseAmount) public {}

    //     function testRevertClaimUnderlyingDuringVestingCliff(uint256 _timeAfterPurchasing) public {}

    //     // Pass scenarios

    //     function testClaimUnderlyingAfterVestingEnd(uint256 _timeAfterPurchasing) public {}

    //     function testClaimUnderlyingDuringVestingWindow(uint256 _timeAfterPurchasing) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         claimUnderlyingMutlipleEntries()
    //     //////////////////////////////////////////////////////////////*/

    //     function testClaimUnderlyingMultipleEntries() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         transfer()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function revertTransferNotOwner() public {}

    //     // Pass scenarios

    //     function testTransfer() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         transferVestingShare()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testTransferVestingShareWrongTokenId(uint256 _shareAmount) public {}

    //     function testTransferShareZero() public {}

    //     function testTransferShareTooHigh(uint256 _shareAmount) public {}

    //     // Pass scenarios

    //     function testTransferShare(uint256 _shareAmount) public {}

    //     // /*//////////////////////////////////////////////////////////////
    //     //                  Scenarios with precision error
    //     // //////////////////////////////////////////////////////////////*/

    //     function testScenarioWithPrecisionErrorPurchaserSide() public {}

    //     function testScenarioWithPrecisionErrorHolderSide() public {}

    //     // /*//////////////////////////////////////////////////////////////
    //     //                           largePool
    //     // //////////////////////////////////////////////////////////////*/

    //     function testTenThousandUserPool() public {}

    //     // /*//////////////////////////////////////////////////////////////
    //     //                           merkleTree
    //     // //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function tesReverttNoIpfsHashFailure() public {}

    //     function testRevertNoNftListFailure() public {}

    //     function testRevertNoAllowListFailure() public {}

    //     function testRevertPurchaseAmountTooHighFailure() public {}

    //     function testRevertInvalidProofFailure() public {}

    //     function testRevertNotMessageSenderFailure(address _investor) public {}

    //     function testRevertAlreadyPurchasedTokensFailure() public {}

    //     // Pass scenarios

    //     function testMerklePurchase() public {}

    /*//////////////////////////////////////////////////////////////
                                events
    //////////////////////////////////////////////////////////////*/

    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);

    event WithdrewExcess(address UpFrontDealAddress, uint256 amountWithdrawn);

    event AcceptDeal(
        address indexed user,
        uint256 amountPurchased,
        uint256 totalPurchased,
        uint256 amountDealTokens,
        uint256 totalDealTokens
    );
}
