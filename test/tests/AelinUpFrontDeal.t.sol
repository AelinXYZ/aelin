// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {ICryptoPunks} from "contracts/interfaces/ICryptoPunks.sol";

contract AelinUpFrontDealTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    address dealCreatorAddress = address(0x1234);

    address dealAddress;
    address dealAddressAllowDeallocation;
    address dealAddressOverFullDeposit;
    address dealAddressAllowList;
    address dealAddressNftGating721;
    address dealAddressNftGatingPunks;
    address dealAddressNftGating1155;

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

        // Allow List
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

        // Nft Gating
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](2);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](2);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules721[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules721[0].purchaseAmount = 1e20;
        nftCollectionRules721[0].purchaseAmountPerToken = true;
        nftCollectionRules721[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules721[1].purchaseAmount = 1e22;
        nftCollectionRules721[1].purchaseAmountPerToken = false;

        nftCollectionRulesPunks[0].collectionAddress = address(collectionAddress1);
        nftCollectionRulesPunks[0].purchaseAmount = 1e20;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = true;
        nftCollectionRulesPunks[1].collectionAddress = address(punks);
        nftCollectionRulesPunks[1].purchaseAmount = 1e22;
        nftCollectionRulesPunks[1].purchaseAmountPerToken = false;

        nftCollectionRules1155[0].collectionAddress = address(collectionAddress4);
        nftCollectionRules1155[0].purchaseAmount = 1e20;
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
        nftCollectionRules1155[1].tokenIds[0] = 10;
        nftCollectionRules1155[1].tokenIds[1] = 20;
        nftCollectionRules1155[1].minTokensEligible[0] = 1000;
        nftCollectionRules1155[1].minTokensEligible[1] = 2000;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1e18
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
            allowListInitEmpty,
            0
        );

        dealAddressAllowDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListInitEmpty,
            0
        );

        dealAddressOverFullDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty,
            1e36
        );

        dealAddressAllowList = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInit,
            1e35
        );

        dealAddressNftGating721 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721,
            allowListInitEmpty,
            1e35
        );

        dealAddressNftGatingPunks = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesPunks,
            allowListInitEmpty,
            1e35
        );

        dealAddressNftGating1155 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules1155,
            allowListInitEmpty,
            1e35
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            initialize
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
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
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
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
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
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
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).vestingExpiry(), 0);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
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
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry(),
            block.timestamp + 10 days + 60 days + 365 days
        );
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
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
        assertEq(AelinUpFrontDeal(dealAddressAllowList).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressAllowList).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        assertFalse(tempBool);
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressNftGating721).dealConfig();
        assertFalse(tempBool);
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
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGatingPunks).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealConfig();
        assertFalse(tempBool);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGatingPunks).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, , tempBool) = AelinUpFrontDeal(dealAddressNftGatingPunks).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGatingPunks)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress1));
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // deal data
        (tempString, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 3e18);
        (, , tempUint, , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 1e28);
        (, , , tempUint, , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 365 days);
        (, , , , , tempUint, ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertEq(tempUint, 60 days);
        (, , , , , , tempBool) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        assertFalse(tempBool);
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
        assertEq(tempUintArray2[0], 100);
        assertEq(tempUintArray2[1], 200);
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

    function testCannotCallInitializeTwice() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1e18
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

        vm.expectRevert("can only initialize once");
        AelinUpFrontDeal(dealAddress).initialize(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty,
            msg.sender,
            aelinTreasury,
            address(testEscrow)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        pre underlying deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotAcceptDealBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.prank(_testAddress);
        vm.expectRevert("deal token not yet deposited");
        AelinUpFrontDeal(dealAddress).acceptDeal(nftPurchaseList, 1e18);
    }

    function testPurchaserCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit not complete");
        AelinUpFrontDeal(dealAddress).purchaserClaim();
    }

    function testSponsorCannotClaimBeforeDeposit() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("underlying deposit not complete");
        AelinUpFrontDeal(dealAddress).sponsorClaim();
    }

    function testHolderCannotClaimBeforeDeposit() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("underlying deposit not complete");
        AelinUpFrontDeal(dealAddress).holderClaim();
    }

    function testTreasuryCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit not complete");
        AelinUpFrontDeal(dealAddress).feeEscrowClaim();
    }

    function testCannotClaimUnderlyingBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit not complete");
        AelinUpFrontDeal(dealAddress).claimUnderlying();
    }

    function testClaimableBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        uint256 result = AelinUpFrontDeal(dealAddress).claimableUnderlyingTokens(_testAddress);
        assertEq(result, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        deposit underlying tokens
    //////////////////////////////////////////////////////////////*/

    function testOnlyHolderCanDepositUnderlying(address _testAddress, uint256 _depositAmount) public {
        vm.assume(_testAddress != address(0xDEAD));
        vm.prank(_testAddress);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
    }

    function testDepositUnderlyingNotEnoughBalance(uint256 _depositAmount, uint256 _holderBalance) public {
        vm.assume(_holderBalance < _depositAmount);
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), _holderBalance);
        underlyingDealToken.approve(address(dealAddress), _holderBalance);
        vm.expectRevert("not enough balance");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
    }

    function testDepositUnderlyingAfterComplete(uint256 _depositAmount) public {
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddressOverFullDeposit).depositUnderlyingTokens(_depositAmount);
    }

    function testPartialThenFullDepositUnderlying(uint256 _firstDepositAmount, uint256 _secondDepositAmount) public {
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        // first deposit
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        (bool success, uint256 result) = SafeMath.tryAdd(_firstDepositAmount, _secondDepositAmount);
        vm.assume(success);
        vm.assume(result >= underlyingDealTokenTotal);
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(dealAddress);
        vm.assume(_firstDepositAmount < underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), address(0xDEAD), _firstDepositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_firstDepositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddress);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _firstDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);
        // second deposit
        balanceBeforeDeposit = balanceAfterDeposit;
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), address(0xDEAD), _secondDepositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_secondDepositAmount);
        balanceAfterDeposit = underlyingDealToken.balanceOf(dealAddress);
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _secondDepositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);
        vm.stopPrank();
    }

    // deposit full underlying then revert when trying to deposit again after
    function testDepositUnderlyingFullDeposit(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        uint256 balanceBeforeDeposit = underlyingDealToken.balanceOf(address(dealAddress));
        vm.assume(_depositAmount >= underlyingDealTokenTotal - balanceBeforeDeposit);
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectEmit(true, false, false, false);
        emit DealFullyFunded(
            address(dealAddress),
            block.timestamp,
            block.timestamp + 10 days,
            block.timestamp + 10 days + 60 days,
            block.timestamp + 10 days + 60 days + 365 days
        );
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), address(0xDEAD), _depositAmount);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        uint256 balanceAfterDeposit = underlyingDealToken.balanceOf(address(dealAddress));
        assertEq(balanceAfterDeposit, balanceBeforeDeposit + _depositAmount);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        vm.expectRevert("already deposited the total");
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        Set / Accept Holder
    //////////////////////////////////////////////////////////////*/

    function testSetHolder(address _futureHolder) public {
        vm.prank(address(0xDEAD));
        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddress).futureHolder(), address(_futureHolder));
        (, , , , address holderAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(holderAddress, address(0xDEAD));
    }

    function testFailSetHolder() public {
        vm.prank(address(0x1337));
        AelinUpFrontDeal(dealAddress).setHolder(msg.sender);
        assertEq(AelinUpFrontDeal(dealAddress).futureHolder(), msg.sender);
    }

    function testFuzzAcceptHolder(address _futureHolder) public {
        vm.prank(address(0xDEAD));
        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        vm.prank(address(_futureHolder));
        vm.expectEmit(false, false, false, false);
        emit SetHolder(_futureHolder);
        AelinUpFrontDeal(dealAddress).acceptHolder();
        (, , , , address holderAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(holderAddress, address(_futureHolder));
    }

    /*//////////////////////////////////////////////////////////////
                                events
    //////////////////////////////////////////////////////////////*/

    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );

    event DealFullyFunded(
        address indexed upFrontDealAddress,
        uint256 timestamp,
        uint256 purchaseExpiryTimestamp,
        uint256 vestingCliffExpiryTimestamp,
        uint256 vestingExpiryTimestamp
    );

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);
}
