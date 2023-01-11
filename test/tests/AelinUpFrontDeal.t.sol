// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
import "../../contracts/libraries/MerkleTree.sol";
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

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;
    IAelinUpFrontDeal.UpFrontDealConfig public sharedDealConfig;
    MerkleTree.UpFrontMerkleData public merkleDataEmpty;

    address dealCreatorAddress = address(0xBEEF);

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

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](2);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](2);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = new AelinNftGating.NftCollectionRules[](2);

        // ERC721 collection
        nftCollectionRules721[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules721[0].purchaseAmount = 1e20;
        nftCollectionRules721[0].purchaseAmountPerToken = true;
        nftCollectionRules721[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules721[1].purchaseAmount = 1e22;
        nftCollectionRules721[1].purchaseAmountPerToken = false;

        // Punk collection
        nftCollectionRulesPunks[0].collectionAddress = address(collectionAddress1);
        nftCollectionRulesPunks[0].purchaseAmount = 1e20;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = true;
        nftCollectionRulesPunks[1].collectionAddress = address(punks);
        nftCollectionRulesPunks[1].purchaseAmount = 1e22;
        nftCollectionRulesPunks[1].purchaseAmountPerToken = false;

        // ERC1155 collection
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
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddress)), 0);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
    }

    function testInitializeAllowDeallocation() public {}

    function testInitializeOverFullDeposit() public {}

    function testInitializeAllowList() public {}

    function testInitializeNftGating721() public {}

    function testInitializeNftGatingMultiple721() public {}

    function testInitializeNftGatingPunks() public {}

    function testInitializeNftGating721AndPunks() public {}

    function testInitializeNftGating1155() public {}

    function testInitializeNftGatingMultiple1155() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         pre depositUnderlyingTokens()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertCannotAcceptDealBeforeDeposit(address _testAddress) public {}

    //     function testRevertPurchaserCannotClaimBeforeDeposit(address _testAddress) public {}

    //     function testRevertSponsorCannotClaimBeforeDeposit() public {}

    //     function testRevertHolderCannotClaimBeforeDeposit() public {}

    //     function testRevertTreasuryCannotClaimBeforeDeposit(address _testAddress) public {}

    //     function testRevertCannotClaimUnderlyingBeforeDeposit(address _testAddress, uint256 _tokenId) public {}

    //     // Pass scenarios

    //     function testClaimableBeforeDeposit(address _testAddress, uint256 _tokenId) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         depositUnderlyingTokens()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertOnlyHolderCanDepositUnderlying(address _testAddress, uint256 _depositAmount) public {}

    //     function testRevertDepositUnderlyingNotEnoughBalance(uint256 _depositAmount, uint256 _holderBalance) public {}

    //     function testRevertDepositUnderlyingAfterComplete(uint256 _depositAmount) public {}

    //     // Pass scenarios

    //     function testPartialThenFullDepositUnderlying(uint256 _firstDepositAmount, uint256 _secondDepositAmount) public {}

    //     function testDepositUnderlyingFullDeposit(uint256 _depositAmount) public {}

    //     function testDirectUnderlyingDeposit() public {}

    //     /*//////////////////////////////////////////////////////////////
    //                         setHolder() / acceptHolder()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertOnlyHolderCanSetNewHolder(address _futureHolder) public {}

    //     function testRevertOnlyDesignatedHolderCanAccept() public {}

    //     // Pass scenarios

    //     function testFuzzSetHolder(address _futureHolder) public {}

    //     function testFuzzAcceptHolder(address _futureHolder) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                               vouch()
    //     //////////////////////////////////////////////////////////////*/

    //     function testFuzzVouchForDeal(address _attestant) public {
    //         vm.prank(_attestant);
    //         vm.expectEmit(false, false, false, false, address(dealAddress));
    //         emit Vouch(_attestant);
    //         AelinUpFrontDeal(dealAddress).vouch();
    //     }

    //     /*//////////////////////////////////////////////////////////////
    //                               disavow()
    //     //////////////////////////////////////////////////////////////*/

    //     function testFuzzDisavowForDeal(address _attestant) public {
    //         vm.prank(_attestant);
    //         vm.expectEmit(false, false, false, false, address(dealAddress));
    //         emit Disavow(_attestant);
    //         AelinUpFrontDeal(dealAddress).disavow();
    //     }

    //     /*//////////////////////////////////////////////////////////////
    //                             withdrawExcess()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertOnlyHolderCanCallWithdrawExcess(address _testAddress) public {}

    //     function testRevertNoExcessToWithdraw(uint256 _depositAmount) public {}

    //     // Pass scenarios

    //     function testWithdrawExcess(uint256 _depositAmount) public {}

    //     /*//////////////////////////////////////////////////////////////
    //                               acceptDeal()
    //     //////////////////////////////////////////////////////////////*/

    //     // Revert scenarios

    //     function testRevertAcceptDealBeforeDepositComplete(address _user, uint256 _purchaseAmount) public {}

    //     function testRevertAcceptDealNotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {}

    //     function testRevertAcceptDealNotEnoughTokens() public {}

    //     function testRevertAcceptDealOverTotal() public {}

    //     function testRevertAcceptDealNotInAllowList(address _user, uint256 _purchaseAmount) public {}

    //     function testRevertAcceptDealOverAllowListAllocation(uint256 _purchaseAmount) public {}

    //     function testRevertAcceptDealNoNftList() public {}

    //     function testRevertAcceptDealNoNftPurchaseList() public {}

    //     function testRevertAcceptDealNftCollectionNotInTheList() public {}

    //     function testRevertAcceptDealERC720MustBeOwner() public {}

    //     function testRevertAcceptDealPunksMustBeOwner() public {}

    //     function testRevertAcceptDealERC721AlreadyUsed() public {}

    //     function testRevertAcceptDealERC721WalletAlreadyUsed() public {}

    //     function testRevertAcceptDealERC721OverAllowed() public {}

    //     function testRevertAcceptDealERC1155BalanceTooLow() public {}

    //     // Pass scenarios

    //     function testAcceptDealBasic(uint256 _purchaseAmount) public {}

    //     function testAcceptDealMultiplePurchasers() public {}

    //     function testAcceptDealAllowDeallocation() public {}

    //     function testAcceptDealAllowList(uint256 _purchaseAmount1, uint256 _purchaseAmount2, uint256 _purchaseAmount3) public {}

    //     function testAcceptDealERC721(uint256 _purchaseAmount) public {}

    //     function testAcceptDealPunks() public {}

    //     function testAcceptDealERC1155(uint256 _purchaseAmount) public {}

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
}
