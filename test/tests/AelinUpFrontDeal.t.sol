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

    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    uint256 constant BASE = 100 * 10 ** 18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 constant AELIN_FEE = 2 * 10 ** 18;

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
    address user4 = address(0x1340);

    address dealAddressNoDeallocationNoDeposit;
    address dealAddressAllowDeallocationNoDeposit;
    address dealAddressNoDeallocation;
    address dealAddressAllowDeallocation;
    address dealAddressAllowList;
    address dealAddressNftGating721;
    address dealAddressNftGatingPunks;
    address dealAddressNftGatingPunksPerToken;
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
        testAllowListAddresses[0] = user1;
        testAllowListAddresses[1] = user2;
        testAllowListAddresses[2] = user3;
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        allowListInit.allowListAddresses = testAllowListAddresses;
        allowListInit.allowListAmounts = testAllowListAmounts;

        // NFT Gating

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = getPunksCollection(false);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunksPerToken = getPunksCollection(true);
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

        dealAddressNoDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        dealAddressAllowDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        dealAddressNoDeallocation = upFrontDealFactory.createUpFrontDeal(
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

        dealAddressNftGatingPunksPerToken = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesPunksPerToken,
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
        underlyingDealToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowList), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowList).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGatingPunks), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGatingPunks).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGatingPunksPerToken), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).depositUnderlyingTokens(1e35);

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

    function getAllowList() public view returns (AelinAllowList.InitData memory) {
        AelinAllowList.InitData memory allowList;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = user1;
        testAllowListAddresses[1] = user2;
        testAllowListAddresses[2] = user3;
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

    function getPunksCollection(bool _purchaseIsPerToken) public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRulesPunks[0].collectionAddress = address(punks);
        nftCollectionRulesPunks[0].purchaseAmount = 1e22;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = _purchaseIsPerToken;

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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).initialize(
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
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = getPunksCollection(false);
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

    function testInitializeNoDeallocationNoDeposit() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit)), 0);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).tokenCount(), 0);
        // underlying hasn't been deposited yet so deal has't started
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertFalse(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeAllowDeallocationNoDeposit() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressAllowDeallocationNoDeposit)), 0);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).tokenCount(), 0);
        // underlying hasn't been deposited yet so deal has't started
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 0);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertTrue(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getNftGatingDetails(
            address(0),
            address(0),
            0
        );
        assertFalse(tempBool);
    }

    function testInitializeNoDeallocation() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNoDeallocation)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertFalse(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testInitializeAllowDeallocation() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressAllowDeallocation)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount(), 0);
        // underlying hasn't been deposited yet so deal has't started
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );
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
        assertEq(AelinUpFrontDeal(dealAddressAllowList).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // test allow list
        address[] memory tempAddressArray;
        uint256[] memory tempUintArray;
        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = user1;
        testAllowListAddresses[1] = user2;
        testAllowListAddresses[2] = user3;
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        (tempAddressArray, tempUintArray, , tempBool) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(address(0));
        assertTrue(tempBool);
        assertEq(testAllowListAddresses.length, tempAddressArray.length);
        assertEq(tempAddressArray[0], user1);
        assertEq(tempAddressArray[1], user2);
        assertEq(tempAddressArray[2], user3);
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).tokenCount(), 0);
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
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).tokenCount(), 0);
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).tokenCount(), 0);
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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, 1e18);
        vm.stopPrank();
    }

    function testRevertPurchaserCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaserClaim();
        vm.stopPrank();
    }

    function testRevertSponsorCannotClaimBeforeDeposit() public {
        vm.prank(dealCreatorAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertHolderCannotClaimBeforeDeposit() public {
        vm.prank(dealHolderAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).holderClaim();
        vm.stopPrank();
    }

    function testRevertTreasuryCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).feeEscrowClaim();
        vm.stopPrank();
    }

    function testRevertCannotClaimUnderlyingBeforeDeposit(address _testAddress, uint256 _tokenId) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).claimUnderlying(_tokenId);
        vm.stopPrank();
    }

    // Pass scenarios

    function testClaimableBeforeDeposit(address _testAddress, uint256 _tokenId) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).claimableUnderlyingTokens(_tokenId), 0);
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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testRevertDepositUnderlyingNotEnoughBalance(uint256 _depositAmount, uint256 _holderBalance) public {
        vm.assume(_holderBalance < _depositAmount);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, _holderBalance);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), _holderBalance);
        vm.expectRevert("not enough balance");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    function testRevertDepositUnderlyingAfterComplete(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressNoDeallocation).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    // Pass scenarios

    function testPartialThenFullDepositUnderlying(uint256 _firstDepositAmount, uint256 _secondDepositAmount) public {
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);

        // first deposit
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        (bool success, uint256 result) = SafeMath.tryAdd(_firstDepositAmount, _secondDepositAmount);
        vm.assume(success);
        vm.assume(result >= underlyingDealTokenTotal);
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        vm.assume(_firstDepositAmount < underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _firstDepositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_firstDepositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _firstDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(), 0);

        // second deposit
        balanceBeforeDeposit = balanceAfterDeposit;
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _secondDepositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_secondDepositAmount);
        balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _secondDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );

        vm.stopPrank();
    }

    function testDepositUnderlyingFullDeposit(uint256 _depositAmount) public {
        vm.startPrank(dealHolderAddress);

        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);

        // deposit initiated
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, _depositAmount);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _depositAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );

        // should revert when trying to deposit again
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);

        vm.stopPrank();
    }

    function testDirectUnderlyingDeposit(address _depositor, uint256 _depositAmount) public {
        vm.assume(_depositor != dealHolderAddress);
        vm.assume(_depositor != address(0));
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.startPrank(_depositor);

        // random wallet sends the funds
        deal(address(underlyingDealToken), _depositor, type(uint256).max);
        underlyingDealToken.transfer(dealAddressNoDeallocationNoDeposit, _depositAmount);
        assertEq(
            underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit)),
            _depositAmount + balanceBeforeDeposit
        );
        assertGe(underlyingDealToken.balanceOf(address(dealAddressNoDeallocationNoDeposit)), underlyingDealTokenTotal);

        // deposit is still not complete
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(), 0);

        // depositUnderlyingTokens() still needs to be called
        vm.stopPrank();
        vm.startPrank(dealHolderAddress);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), dealHolderAddress, 0);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(0);

        // deposit is now flagged as completed
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiry(),
            block.timestamp + 10 days + 60 days
        );
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );

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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(holderAddress, dealHolderAddress);
        vm.stopPrank();
    }

    function testRevertOnlyDesignatedHolderCanAccept(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(dealHolderAddress);

        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).futureHolder(), _futureHolder);
        vm.expectRevert("only future holder can access");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptHolder();
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(holderAddress, dealHolderAddress);

        vm.stopPrank();
    }

    // Pass scenarios

    function testSetAndAcceptHolder(address _futureHolder) public {
        vm.assume(_futureHolder != dealHolderAddress);
        vm.startPrank(dealHolderAddress);
        address temHolderAddress;

        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).futureHolder(), _futureHolder);
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(temHolderAddress, dealHolderAddress);
        vm.stopPrank();

        vm.startPrank(_futureHolder);
        vm.expectEmit(false, false, false, false);
        emit SetHolder(_futureHolder);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptHolder();
        (, , , , temHolderAddress, , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(temHolderAddress, _futureHolder);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  vouch()
        //////////////////////////////////////////////////////////////*/

    function testFuzzVouchForDeal(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddressNoDeallocationNoDeposit));
        emit Vouch(_attestant);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vouch();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  disavow()
        //////////////////////////////////////////////////////////////*/

    function testFuzzDisavowForDeal(address _attestant) public {
        vm.startPrank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddressNoDeallocationNoDeposit));
        emit Disavow(_attestant);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).disavow();
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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        vm.stopPrank();
    }

    function testRevertNoExcessToWithdraw(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        vm.assume(_depositAmount <= underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        vm.expectRevert("no excess to withdraw");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        vm.stopPrank();
    }

    // Pass scenarios

    function testWithdrawExcess(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        vm.assume(_depositAmount > underlyingDealTokenTotal);
        vm.startPrank(dealHolderAddress);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterTransfer = underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit);
        uint256 expectedWithdraw = balanceAfterTransfer - underlyingDealTokenTotal;
        vm.expectEmit(false, false, false, false);
        emit WithdrewExcess(address(dealAddressNoDeallocationNoDeposit), expectedWithdraw);
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).withdrawExcess();
        assertEq(underlyingDealToken.balanceOf(dealAddressNoDeallocationNoDeposit), underlyingDealTokenTotal);

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
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        // deposit to start purchase period
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocationNoDeposit), type(uint256).max);
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).depositUnderlyingTokens(underlyingDealTokenTotal);
        vm.stopPrank();

        // warp past purchase period and try to accept deal
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.startPrank(_user);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);

        // try on a contract that was deposited during intialize
        purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotEnoughTokens() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint256 tokenAmount = 100;
        vm.prank(user1);
        deal(address(purchaseToken), user1, tokenAmount);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectRevert("not enough purchaseToken");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, tokenAmount + 1);
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
            dealAddressNoDeallocation
        ).dealConfig();

        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;

        // User 1 tries to deposit more than the total purchase amount
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        uint256 expectedPoolShareAmount = ((raiseAmount + 1e18) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        assertGt(expectedPoolShareAmount, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, raiseAmount + 1e18);

        // User 1 now deposits less than the total purchase amount
        uint256 purchaseAmount1 = raiseAmount - 2e18;
        expectedPoolShareAmount = (purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount1, purchaseAmount1, expectedPoolShareAmount, expectedPoolShareAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);
        vm.stopPrank();

        // User 2 now deposits more than the total purchase amount
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        uint256 purchaseAmount2 = purchaseAmount1 + 3e18;
        uint256 totalPoolShares = ((purchaseAmount2 + purchaseAmount1) * 10 ** underlyingTokenDecimals) /
            purchaseTokenPerDealToken;
        assertGt(totalPoolShares, underlyingDealTokenTotal);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotInAllowList(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(user4);
        deal(address(purchaseToken), user4, type(uint256).max);
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

    function testRevertAcceptDealEmptyNftList(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        vm.assume(_purchaseAmount > 1e18);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("collection should not be null");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
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

    function testRevertAcceptDealERC72NoTokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collectionAddress1).mint(user2, 1);
        MockERC721(collectionAddress1).mint(user2, 2);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC72InvalidTokenId(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 4;
        tokenIdsArray[1] = 5;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        // We mint the tokens to another user
        MockERC721(collectionAddress1).mint(user2, 1);
        MockERC721(collectionAddress1).mint(user2, 2);
        vm.expectRevert("ERC721: invalid token ID");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC721WalletAlreadyUsed() public {
        vm.startPrank(user1);

        uint256 purchaseAmount = 1e18;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);

        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress2).mint(user1, 1);
        MockERC721(collectionAddress2).mint(user1, 2);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, 1e18);
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, 1e18);

        vm.stopPrank();
    }

    function testRevertAcceptDealERC721OverAllowed(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressNoDeallocation
        ).dealConfig();
        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount > raiseAmount);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);

        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress1).mint(user1, 1);
        MockERC721(collectionAddress1).mint(user1, 2);

        vm.startPrank(user1);
        vm.expectRevert("purchase amount greater than max allocation");
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

    function testRevertAcceptDealPunkAlreadyUsed() public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunksPerToken), type(uint256).max);

        uint256 purchaseAmount = 1e18;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        // Since punks address is hardcoded we need to cheat and link the Mock contract to the address
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);
        uint256[] memory tokenIdsArray = new uint256[](2);
        MockPunks(punks).mint(user1, 1);
        MockPunks(punks).mint(user1, 2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    // User has no tokens at all
    function testRevertAcceptDealERC1155MustBeOwner(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collectionAddress4).mint(user2, 1, 1, "");
        MockERC1155(collectionAddress4).mint(user2, 2, 1, "");
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    // If user has tokens but not enough (balance < minTokensEligible)
    function testRevertAcceptDealERC1155BalanceTooLow(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collectionAddress4).mint(user1, 1, 1, "");
        MockERC1155(collectionAddress4).mint(user1, 2, 1, "");
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC1155NotInPool(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 10;
        tokenIdsArray[1] = 11;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collectionAddress4).mint(user1, 10, 1, "");
        MockERC1155(collectionAddress4).mint(user1, 11, 1, "");
        vm.expectRevert("tokenId not in the pool");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC1155NoTokenIds(uint256 _purchaseAmount) public {
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        uint256[] memory tokenIdsArray = new uint256[](2);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC1155(collectionAddress4).mint(user1, 10, 1, "");
        MockERC1155(collectionAddress4).mint(user1, 11, 1, "");
        vm.expectRevert("tokenId not in the pool");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    // Pass scenarios

    function testAcceptDealBasic(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressNoDeallocation
        ).dealConfig();
        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_purchaseAmount <= raiseAmount);
        uint256 firstPurchase = _purchaseAmount / 4;
        uint256 secondPurchase = firstPurchase;
        uint256 thirdPurchase = _purchaseAmount - firstPurchase - secondPurchase;

        // we compute the numbers for the first deposit
        uint256 poolSharesAmount = (firstPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, firstPurchase, firstPurchase, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1), firstPurchase);

        // we compute the numbers for the second deposit (same user)
        uint256 poolSharesAmount2 = (secondPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            secondPurchase,
            firstPurchase + secondPurchase,
            poolSharesAmount2,
            poolSharesAmount + poolSharesAmount2
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, secondPurchase);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(), poolSharesAmount + poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1), poolSharesAmount + poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), firstPurchase + secondPurchase);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1), firstPurchase + secondPurchase);

        // now with do the same but for a new user
        vm.stopPrank();
        vm.startPrank(user2);
        uint256 poolSharesAmount3 = (thirdPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, thirdPurchase, thirdPurchase, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, thirdPurchase);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares(),
            poolSharesAmount + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user2), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(),
            firstPurchase + secondPurchase + thirdPurchase
        );
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user2), thirdPurchase);

        vm.stopPrank();
    }

    function testAcceptDealAllowDeallocation(
        uint256 _firstPurchase,
        uint256 _secondPurchase,
        uint256 _thirdPurchase
    ) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        uint256 raiseAmount = (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10 ** underlyingTokenDecimals;
        vm.assume(_firstPurchase > 0);
        vm.assume(_secondPurchase > 0);
        vm.assume(_thirdPurchase > 0);
        vm.assume(_firstPurchase < 1e50);
        vm.assume(_secondPurchase < 1e50);
        vm.assume(_thirdPurchase < 1e50);

        vm.assume(_firstPurchase + _secondPurchase + _thirdPurchase > raiseAmount);

        // we compute the numbers for the first deposit
        uint256 poolSharesAmount = (_firstPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, _firstPurchase, _firstPurchase, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _firstPurchase);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1), _firstPurchase);

        // we compute the numbers for the second deposit (same user)
        uint256 poolSharesAmount2 = (_secondPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);

        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            _secondPurchase,
            _firstPurchase + _secondPurchase,
            poolSharesAmount2,
            poolSharesAmount + poolSharesAmount2
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _secondPurchase);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount + poolSharesAmount2);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1),
            poolSharesAmount + poolSharesAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _firstPurchase + _secondPurchase);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1),
            _firstPurchase + _secondPurchase
        );

        // now with do the same but for a new user
        vm.stopPrank();
        vm.startPrank(user2);
        uint256 poolSharesAmount3 = (_thirdPurchase * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, _thirdPurchase, _thirdPurchase, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _thirdPurchase);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(),
            poolSharesAmount + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _firstPurchase + _secondPurchase + _thirdPurchase
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2), _thirdPurchase);

        vm.stopPrank();
    }

    function testAcceptDealAllowList(uint256 _purchaseAmount1, uint256 _purchaseAmount2, uint256 _purchaseAmount3) public {
        uint256 tempAllocatedAmount;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user1);
        vm.assume(_purchaseAmount1 <= tempAllocatedAmount);
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user2);
        vm.assume(_purchaseAmount2 <= tempAllocatedAmount);
        (, , tempAllocatedAmount, ) = AelinUpFrontDeal(dealAddressAllowList).getAllowList(user3);
        vm.assume(_purchaseAmount3 <= tempAllocatedAmount);

        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount1 > 0);
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);
        uint256 poolSharesAmount3 = (_purchaseAmount3 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);

        // first user deposit
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user1), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user1), _purchaseAmount1);
        vm.stopPrank();

        // second user deposit
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1 + poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user2), poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1 + _purchaseAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user2), _purchaseAmount2);
        vm.stopPrank();

        // third user deposit
        vm.startPrank(user3);
        deal(address(purchaseToken), user3, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user3, _purchaseAmount3, _purchaseAmount3, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(),
            poolSharesAmount1 + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).poolSharesPerUser(user3), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2 + _purchaseAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseTokensPerUser(user3), _purchaseAmount3);
        vm.stopPrank();
    }

    function testAcceptDealERC721() public {
        // user setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();

        MockERC721(collectionAddress1).mint(user1, 1);
        MockERC721(collectionAddress1).mint(user1, 2);
        MockERC721(collectionAddress1).mint(user1, 3);
        MockERC721(collectionAddress1).mint(user2, 4);
        MockERC721(collectionAddress1).mint(user2, 5);
        MockERC721(collectionAddress2).mint(user2, 1);
        MockERC721(collectionAddress2).mint(user2, 2);
        MockERC721(collectionAddress2).mint(user2, 3);

        uint256 totalPoolShares;
        uint256 poolSharesAmount;

        // nft gating setup
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // we get the allocation for each collection
        (uint256 purchaseCollection1, , bool purchaseAmountPerToken1, , ) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collectionAddress1));
        (uint256 purchaseCollection2, , bool purchaseAmountPerToken2, , ) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collectionAddress2));

        // checks pre-purchase
        bool walletClaimed;
        bool NftIdUsed;
        bool hasNftList;
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            3
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user2,
            4
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user2,
            5
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            3
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        // case 1: [collection1] user1 max out their allocation with multiple tokens (purchaseAmountPerToken = true)
        vm.startPrank(user1);

        // 2 tokens so double the purchaseAmount
        poolSharesAmount = ((2 * purchaseCollection1) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.assume(poolSharesAmount > 0);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, (2 * purchaseCollection1), (2 * purchaseCollection1), poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1));

        // user1 now purchases again using his last token
        poolSharesAmount = (purchaseCollection1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares += poolSharesAmount;
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](1);
        tokenIdsArray[0] = 3;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            purchaseCollection1,
            (2 * purchaseCollection1) + purchaseCollection1,
            poolSharesAmount,
            totalPoolShares
        );
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection1);
        vm.stopPrank();

        // case 2: [collection2] user2 max out their wallet allocation (purchaseAmountPerToken = false)
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](3);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        tokenIdsArray[2] = 3;
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        // since purchaseAmountPerToken = false, user2 can't buy more than the allocation amount for collection2
        vm.expectRevert("purchase amount greater than max allocation");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, 2 * purchaseCollection2);

        // we then make user2 buy the exact amount
        poolSharesAmount = (purchaseCollection2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        totalPoolShares = poolSharesAmount;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, purchaseCollection2, purchaseCollection2, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection2);

        // user2 is now blacklisted from purchasing again in this collection
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection2);

        // case 3: [collection1] user2 comes back and max out their allocation (purchaseAmountPerToken = true)
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 4;
        tokenIdsArray[1] = 5;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;

        // 2 tokens so double the purchaseAmount
        poolSharesAmount = ((2 * purchaseCollection1) * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user2,
            (2 * purchaseCollection1),
            (2 * purchaseCollection1 + purchaseCollection2),
            poolSharesAmount,
            poolSharesAmount + totalPoolShares
        );
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1));

        // user2 can't reuse the same tokens if they want to purchase again
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection1));
        vm.stopPrank();

        //checks post-purchase
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            1
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user1,
            3
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user2,
            4
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            user2,
            5
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            1
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            2
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            user2,
            3
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function testAcceptDealPunksPerWallet() public {
        // since punks address is hardcoded we need to cheat and link the Mock contract to the address
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // nft gating setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // we get the allocation for each collection
        (uint256 purchaseCollection, , bool purchaseAmountPerToken, , ) = AelinUpFrontDeal(dealAddressNftGatingPunks)
            .getNftCollectionDetails(address(punks));

        // we mint some punks
        MockPunks(punks).mint(user1, 1);
        MockPunks(punks).mint(user1, 2);
        MockPunks(punks).mint(user2, 3);
        MockPunks(punks).mint(user2, 4);

        // checks pre-purchase
        bool walletClaimed;
        bool NftIdUsed;
        bool hasNftList;
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user1,
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user2,
            3
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user2,
            4
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        // user1 tries to invest double the allocated amount because they own 2 punks, but fails
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunks), type(uint256).max);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectRevert("purchase amount greater than max allocation");
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, (2 * purchaseCollection));

        // user1 now purchases half of the allocation
        uint256 purchaseAmount = purchaseCollection / 2;
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);

        // user1 now tries to buy the remaining allocation, but fails
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();

        // user2 tries to buy all the allocation
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunks), type(uint256).max);
        tokenIdsArray[0] = 3;
        tokenIdsArray[1] = 4;
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        poolSharesAmount = (purchaseCollection * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, purchaseCollection, purchaseCollection, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection);

        // user2 now tries to buy some extra tokens, but fails
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseCollection);
        vm.stopPrank();

        //checks post-purchase
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user1,
            1
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user1,
            2
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user2,
            3
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(
            address(punks),
            user2,
            4
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function testAcceptDealPunksPerToken() public {
        // since punks address is hardcoded we need to cheat and link the Mock contract to the address
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // nft gating setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).dealConfig();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        // we get the allocation for each collection
        (uint256 purchaseCollection, , bool purchaseAmountPerToken, , ) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken)
            .getNftCollectionDetails(address(punks));

        // we mint some punks
        MockPunks(punks).mint(user1, 1);
        MockPunks(punks).mint(user1, 2);
        MockPunks(punks).mint(user1, 3);
        MockPunks(punks).mint(user2, 4);
        MockPunks(punks).mint(user2, 5);

        // checks pre-purchase
        bool walletClaimed;
        bool NftIdUsed;
        bool hasNftList;
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user1,
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            3
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            4
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            5
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);

        // user1 invests double the allocated amount because they own 2 punks
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunksPerToken), type(uint256).max);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(punks);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        uint256 purchaseAmount = purchaseCollection * 2;
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);

        // user1 now tries to purchase another 2x allocation with another punk, but fails
        tokenIdsArray = new uint256[](1);
        tokenIdsArray[0] = 3;
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        vm.expectRevert("purchase amount greater than max allocation");
        AelinUpFrontDeal(dealAddressNftGatingPunks).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);

        // user1 now buys the entire allocation with the last punk
        purchaseAmount = purchaseCollection;
        uint256 totalPoolShares = poolSharesAmount;
        poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount * 3, poolSharesAmount, totalPoolShares + poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();

        // user2 buys the entire allocation
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGatingPunksPerToken), type(uint256).max);
        tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 4;
        tokenIdsArray[1] = 5;
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        purchaseAmount = purchaseCollection * 2;
        poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);

        // user2 tries to buy again with the same punks, but fails
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();

        // checks post-purchase
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user1,
            1
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            3
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            4
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGatingPunksPerToken).getNftGatingDetails(
            address(punks),
            user2,
            5
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function testAcceptDealERC1155() public {
        // nft gating setup
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        (uint256 purchaseCollection1, , , , uint256[] memory minTokensEligible1) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collectionAddress4));
        (uint256 purchaseCollection2, , , , uint256[] memory minTokensEligible2) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collectionAddress5));

        // we mint some tokens
        MockERC1155(address(collectionAddress4)).mint(user1, 1, 100, "");
        MockERC1155(address(collectionAddress4)).mint(user1, 2, 100, "");
        MockERC1155(address(collectionAddress5)).mint(user1, 10, 1000, "");
        MockERC1155(address(collectionAddress5)).mint(user1, 20, 2000, "");

        // case 1: [collection4] user1 max out their allocation with the 2 collections
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);

        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](2);
        nftPurchaseList[0].tokenIds[0] = 1;
        nftPurchaseList[0].tokenIds[1] = 2;

        nftPurchaseList[1].collectionAddress = address(collectionAddress5);
        nftPurchaseList[1].tokenIds = new uint256[](2);
        nftPurchaseList[1].tokenIds[0] = 10;
        nftPurchaseList[1].tokenIds[1] = 20;

        // first collection is per token, second is per wallet
        // so total allocation = balanceOf(tokens) * allocationCollection1 + allocationCollection2
        uint256 purchaseAmount = (200 * purchaseCollection1) + purchaseCollection2;
        uint256 poolSharesAmount = (purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        // user can't buy more than purchase amount
        vm.expectRevert("purchase amount greater than max allocation");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount + 1);

        // user1 buys the tokens
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);

        // user1 cannot buy anymore
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, 1);

        // we mint new tokens for both collections
        MockERC1155(address(collectionAddress4)).mint(user1, 1, 100, "");
        MockERC1155(address(collectionAddress5)).mint(user1, 20, 2000, "");

        // it still doesn't work because wallet is blacklisted for collection 2
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, 1);

        // if we only use collection 1, it is working because allocation is per new token
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        uint256 newPurchaseAmount = 100 * purchaseCollection1;
        uint256 newPoolShareAmount = (newPurchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;

        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(
            user1,
            newPurchaseAmount,
            purchaseAmount + newPurchaseAmount,
            newPoolShareAmount,
            newPoolShareAmount + poolSharesAmount
        );
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, newPurchaseAmount);

        // if we only use collection 2, it reverts
        nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddress5);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 20;

        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, 1);

        // checks post-purchase
        (bool walletClaimed, bool NftIdUsed, bool hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftGatingDetails(address(collectionAddress4), user1, 1);
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress4),
            user1,
            2
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress5),
            user1,
            10
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress5),
            user1,
            20
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);

        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPoolShares(), newPoolShareAmount + poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).poolSharesPerUser(user1), newPoolShareAmount + poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPurchasingAccepted(), purchaseAmount + newPurchaseAmount);
        assertEq(
            AelinUpFrontDeal(dealAddressNftGating1155).purchaseTokensPerUser(user1),
            purchaseAmount + newPurchaseAmount
        );

        vm.stopPrank();
    }

    //     /*//////////////////////////////////////////////////////////////
    //                             purchaserClaim()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertPurchaserClaimNotInWindow(address _user) public {
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).purchaserClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim();
        vm.stopPrank();
    }

    function testRevertPurchaserClaimNoShares(address _user) public {
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("no pool shares to claim with");
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim();
        vm.stopPrank();
    }

    // Pass scenarios

    // Does not meet purchaseRaiseMinimum
    function testPurchaserClaimRefund(uint256 _purchaseAmount) public {
        (, uint256 purchaseTokenPerDealToken, uint256 purchaseRaiseMinimum, , , , ) = AelinUpFrontDeal(
            dealAddressNoDeallocation
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.assume(_purchaseAmount > 0);
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user1 accepts the deal with _purchaseAmount < purchaseRaiseMinimum
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1), _purchaseAmount);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount);

        // purchase period is over, user1 tries to claim and gets a refund instead
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, 0, _purchaseAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim();
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max);

        vm.stopPrank();
    }

    function testPurchaserClaimNoDeallocation(uint256 _purchaseAmount) public {
        (
            uint256 underlyingDealTokenTotal,
            uint256 purchaseTokenPerDealToken,
            uint256 purchaseRaiseMinimum,
            ,
            ,
            ,

        ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.assume(_purchaseAmount > purchaseRaiseMinimum);
        vm.assume(_purchaseAmount < 1e50);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);

        // user1 accepts the deal with _purchaseAmount > purchaseRaiseMinimum
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1), _purchaseAmount);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount);

        // purchase period is over and user1 tries to claim
        vm.warp(purchaseExpiry + 1 days);
        uint256 poolSharesForUser = AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1);
        assertEq(poolSharesForUser, poolSharesAmount);
        uint256 adjustedShareAmountForUser = ((BASE - AELIN_FEE - sponsorFee) * poolSharesForUser) / BASE;
        uint256 tokenCount = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(user1, tokenCount, adjustedShareAmountForUser, purchaseExpiry);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser, 0);
        AelinUpFrontDeal(dealAddressNoDeallocation).purchaserClaim();

        // post claim checks
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).poolSharesPerUser(user1), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseTokensPerUser(user1), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(underlyingDealToken.balanceOf(user1), 0);

        // checks if user1 got their vesting token
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).balanceOf(user1), 1);
        assertEq(MockERC721(dealAddressNoDeallocation).ownerOf(tokenCount), user1);
        (uint256 userShare, uint256 lastClaimedAt) = AelinUpFrontDeal(dealAddressNoDeallocation).vestingDetails(tokenCount);
        assertEq(userShare, adjustedShareAmountForUser);
        assertEq(lastClaimedAt, AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry());

        vm.stopPrank();
    }

    function testPurchaserClaimWithDeallocation(uint256 _purchaseAmount1, uint256 _purchaseAmount2) public {
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.assume(_purchaseAmount1 > 0);
        vm.assume(_purchaseAmount2 > 0);
        vm.assume(_purchaseAmount1 < 1e40);
        vm.assume(_purchaseAmount2 < 1e40);
        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount1 > 0);
        vm.assume(poolSharesAmount2 > 0);
        vm.assume(poolSharesAmount1 + poolSharesAmount2 > underlyingDealTokenTotal);

        // user1 accepts the deal
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1), _purchaseAmount1);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount1);
        vm.stopPrank();

        // user2 accepts the deal
        vm.startPrank(user2);
        deal(address(purchaseToken), user2, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user2, _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2), _purchaseAmount2);
        assertEq(IERC20(address(purchaseToken)).balanceOf(user2), type(uint256).max - _purchaseAmount2);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user1 tries to claim
        vm.startPrank(user1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1), poolSharesAmount1);
        uint256 adjustedShareAmountForUser1 = (((poolSharesAmount1 * underlyingDealTokenTotal) /
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares()) * (BASE - AELIN_FEE - sponsorFee)) / BASE;
        uint256 refundAmount = _purchaseAmount1 -
            ((_purchaseAmount1 * underlyingDealTokenTotal) /
                AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares());
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(), 0);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(
            user1,
            AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(),
            adjustedShareAmountForUser1,
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry()
        );
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user1, adjustedShareAmountForUser1, refundAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim();
        vm.stopPrank();

        // post claim checks
        assertEq(IERC20(address(purchaseToken)).balanceOf(user1), type(uint256).max - _purchaseAmount1 + refundAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user1), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user1), 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(underlyingDealToken.balanceOf(user1), 0);

        // user2 tries to claim
        vm.startPrank(user2);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2), poolSharesAmount2);
        uint256 adjustedShareAmountForUser2 = (((poolSharesAmount2 * underlyingDealTokenTotal) /
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares()) * (BASE - AELIN_FEE - sponsorFee)) / BASE;
        refundAmount =
            _purchaseAmount2 -
            ((_purchaseAmount2 * underlyingDealTokenTotal) /
                AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares());
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(), 1);
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(
            user2,
            AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount(),
            adjustedShareAmountForUser2,
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry()
        );
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(user2, adjustedShareAmountForUser2, refundAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim();
        vm.stopPrank();

        // post claim checks
        assertEq(IERC20(address(purchaseToken)).balanceOf(user2), type(uint256).max - _purchaseAmount2 + refundAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).poolSharesPerUser(user2), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseTokensPerUser(user2), 0);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2
        );
        assertEq(underlyingDealToken.balanceOf(user2), 0);

        // checks if user1 got their vesting token
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user1), 1);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(0), user1);
        (uint256 userShare, uint256 lastClaimedAt) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(0);
        assertEq(userShare, adjustedShareAmountForUser1);
        assertEq(lastClaimedAt, AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry());

        // checks if user2 got their vesting token
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).balanceOf(user2), 1);
        assertEq(MockERC721(dealAddressAllowDeallocation).ownerOf(1), user2);
        (userShare, lastClaimedAt) = AelinUpFrontDeal(dealAddressAllowDeallocation).vestingDetails(1);
        assertEq(userShare, adjustedShareAmountForUser2);
        assertEq(lastClaimedAt, AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry());
    }

    //     /*//////////////////////////////////////////////////////////////
    //                             sponsorClaim()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertSponsorClaimNotInWindow(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).sponsorClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimFailMinimumRaise(uint256 _purchaseAmount, address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != dealCreatorAddress);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, uint256 purchaseRaiseMinimum, , , , ) = AelinUpFrontDeal(
            dealAddressNoDeallocation
        ).dealConfig();
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount < purchaseMinimum
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim();
        vm.stopPrank();

        // sponsor tries to call sponsorClaim() and it reverts
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimNotSponsor(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_user != dealCreatorAddress);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, uint256 purchaseRaiseMinimum, , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        vm.assume(_purchaseAmount >= purchaseRaiseMinimum);
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount >= purchaseMinimum
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("must be sponsor");
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimAlreadyClaimed(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_user != dealCreatorAddress);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, uint256 purchaseRaiseMinimum, , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        vm.assume(_purchaseAmount >= purchaseRaiseMinimum);
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount >= purchaseMinimum
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // sponsor now claims
        vm.startPrank(dealCreatorAddress);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim();

        // sponsor tries to claim again and it fails
        vm.expectRevert("sponsor already claimed");
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    // Pass scenarios

    function testSponsorClaimNoDeallocation(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (
            uint256 underlyingDealTokenTotal,
            uint256 purchaseTokenPerDealToken,
            uint256 purchaseRaiseMinimum,
            ,
            ,
            ,

        ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry();
        vm.assume(_purchaseAmount > purchaseRaiseMinimum);
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount < underlyingDealTokenTotal);

        // user1 accepts the deal
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(purchaseExpiry + 1 days);

        // sponsor now claims and gets a vesting token
        vm.startPrank(dealCreatorAddress);
        uint256 tokenCount = AelinUpFrontDeal(dealAddressNoDeallocation).tokenCount();
        uint256 totalSold = AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares();
        uint256 shareAmount = (totalSold * sponsorFee) / BASE;
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(dealCreatorAddress, tokenCount, shareAmount, purchaseExpiry);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(dealCreatorAddress, shareAmount);
        AelinUpFrontDeal(dealAddressNoDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    function testSponsorClaimWithDeallocation(uint256 _purchaseAmount) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);

        // user1 accepts the deal
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(purchaseExpiry + 1 days);

        // sponsor now claims and gets a vesting token
        vm.startPrank(dealCreatorAddress);
        uint256 tokenCount = AelinUpFrontDeal(dealAddressAllowDeallocation).tokenCount();
        uint256 shareAmount = (underlyingDealTokenTotal * sponsorFee) / BASE;
        vm.expectEmit(true, true, false, true);
        emit VestingTokenMinted(dealCreatorAddress, tokenCount, shareAmount, purchaseExpiry);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(dealCreatorAddress, shareAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim();
        vm.stopPrank();
    }

    //     /*//////////////////////////////////////////////////////////////
    //                             holderClaim()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertHolderClaimNotInWindow(address _user) public {
        vm.startPrank(_user);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).holderClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    function testRevertHolderClaimNotHolder(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_user != dealHolderAddress);
        vm.assume(_purchaseAmount > 0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // user tries to call sponsorClaim() and it reverts
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    function testRevertHolderClaimAlreadyClaimed(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_purchaseAmount > 0);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // holder calls holderClaim()
        vm.startPrank(dealHolderAddress);
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();

        // holder calls holderClaim() again and it reverts
        vm.expectRevert("holder already claimed");
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        vm.stopPrank();
    }

    // Pass scenarios

    function testHolderClaimFailMinimumRaise(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, uint256 purchaseRaiseMinimum, , , , ) = AelinUpFrontDeal(
            dealAddressNoDeallocation
        ).dealConfig();
        vm.assume(_purchaseAmount < purchaseRaiseMinimum);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);

        // user accepts the deal with purchaseAmount < purchaseMinimum
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // holder tries to call sponsorClaim() and gets all their underlying deal tokens back
        vm.startPrank(dealHolderAddress);
        uint256 amountRefund = underlyingDealToken.balanceOf(address(dealAddressAllowDeallocation));
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            0,
            address(underlyingDealToken),
            amountRefund,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).holderClaim();
        uint256 amountAfterClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        assertEq(amountAfterClaim - amountBeforeClaim, amountRefund);
        vm.stopPrank();
    }

    function testHolderClaimNoDeallocation(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (
            uint256 underlyingDealTokenTotal,
            uint256 purchaseTokenPerDealToken,
            uint256 purchaseRaiseMinimum,
            ,
            ,
            ,

        ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        vm.assume(_purchaseAmount > purchaseRaiseMinimum);
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount < underlyingDealTokenTotal);

        // user accepts the deal with purchaseMinimum  < purchaseAmount < deal total
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressNoDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressNoDeallocation).purchaseExpiry() + 1 days);

        // holder calls sponsorClaim()
        vm.startPrank(dealHolderAddress);
        uint256 amountRaise = purchaseToken.balanceOf(dealAddressNoDeallocation);
        uint256 amountRefund = underlyingDealTokenTotal - poolSharesAmount;
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 feeAmount = (AelinUpFrontDeal(dealAddressNoDeallocation).totalPoolShares() * AELIN_FEE) / BASE;
        assertEq(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow()), address(0));
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            amountRaise,
            address(underlyingDealToken),
            underlyingDealTokenTotal - poolSharesAmount,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressNoDeallocation).holderClaim();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress) - amountBeforeClaim, amountRefund);
        // this function also calls the claim for the protocol fee
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressNoDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    function testHolderClaimWithDeallocation(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);

        // user accepts the deal with purchaseAmount > deal total
        vm.startPrank(_user);
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // purchase period is now over
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);

        // holder calls sponsorClaim()
        vm.startPrank(dealHolderAddress);
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(dealHolderAddress);
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10 ** underlyingTokenDecimals;
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            dealHolderAddress,
            address(purchaseToken),
            totalIntendedRaise,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        assertEq(underlyingDealToken.balanceOf(dealHolderAddress), amountBeforeClaim);
        // this function also calls the claim for the protocol fee
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    //     /*//////////////////////////////////////////////////////////////
    //                             feeEscrowClaim()
    //     //////////////////////////////////////////////////////////////*/

    // Revert scenarios

    function testRevertEscrowClaimNotInWindow() public {}

    // Pass scenarios

    function testEscrowClaimNoDeallocation(address _address) public {}

    function testEscrowClaimWithDeallocation(address _address) public {}

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

    event VestingTokenMinted(address indexed user, uint256 indexed tokenId, uint256 amount, uint256 lastClaimedAt);

    event ClaimDealTokens(address indexed user, uint256 amountMinted, uint256 amountPurchasingReturned);

    event SponsorClaim(address indexed sponsor, uint256 amountMinted);

    event HolderClaim(
        address indexed holder,
        address purchaseToken,
        uint256 amountClaimed,
        address underlyingToken,
        uint256 underlyingRefund,
        uint256 timestamp
    );

    event FeeEscrowClaim(address indexed aelinFeeEscrow, address indexed underlyingTokenAddress, uint256 amount);
}
