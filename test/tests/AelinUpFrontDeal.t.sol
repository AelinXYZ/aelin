// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
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

    uint256 constant BASE = 100 * 10**18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10**18;
    uint256 constant AELIN_FEE = 2 * 10**18;

    address dealCreatorAddress = address(0xBEEF);

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

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;
    IAelinUpFrontDeal.UpFrontDealConfig public sharedDealConfig;
    IAelinUpFrontDeal.UpFrontMerkleData public merkleDataEmpty;

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

        // Nft Gating

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

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            ipfsHash: 0x0000000000000000000000000000000000000000000000000000000000000000,
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
        assertEq(AelinUpFrontDeal(dealAddressAllowList).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddressAllowList).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        // deal data
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowList).dealData();
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
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGating721).dealData();
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
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGatingPunks).dealData();
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
        (tempString, , , , , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(0xDEAD));
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
        assertEq(tempAddress, address(0xBEEF));
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealData();
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

    function testCannotCallInitializeTwice() public {
        AelinAllowList.InitData memory allowListInitEmpty;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 100,
            ipfsHash: 0,
            merkleRoot: 0
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

        vm.expectRevert("can only init once");
        AelinUpFrontDeal(dealAddress).initialize(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty,
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
        vm.expectRevert("deal token not deposited");
        AelinUpFrontDeal(dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, 1e18);
    }

    function testPurchaserCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).purchaserClaim();
    }

    function testSponsorCannotClaimBeforeDeposit() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).sponsorClaim();
    }

    function testHolderCannotClaimBeforeDeposit() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).holderClaim();
    }

    function testTreasuryCannotClaimBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).feeEscrowClaim();
    }

    function testCannotClaimUnderlyingBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).claimUnderlying();
    }

    function testClaimableBeforeDeposit(address _testAddress) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).claimableUnderlyingTokens(_testAddress);
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
                        setHolder / acceptHolder
    //////////////////////////////////////////////////////////////*/

    function testSetHolder(address _futureHolder) public {
        vm.prank(address(0xDEAD));
        AelinUpFrontDeal(dealAddress).setHolder(_futureHolder);
        assertEq(AelinUpFrontDeal(dealAddress).futureHolder(), address(_futureHolder));
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
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
        (, , , , address holderAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(holderAddress, address(_futureHolder));
    }

    /*//////////////////////////////////////////////////////////////
                              vouch
    //////////////////////////////////////////////////////////////*/

    function testFuzzVouchForDeal(address _attestant) public {
        vm.prank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Vouch(_attestant);
        AelinUpFrontDeal(dealAddress).vouch();
    }

    /*//////////////////////////////////////////////////////////////
                              disavow
    //////////////////////////////////////////////////////////////*/

    function testFuzzDisavowForDeal(address _attestant) public {
        vm.prank(_attestant);
        vm.expectEmit(false, false, false, false, address(dealAddress));
        emit Disavow(_attestant);
        AelinUpFrontDeal(dealAddress).disavow();
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawExcess
    //////////////////////////////////////////////////////////////*/

    function testOnlyHolderCanCallWithdrawExcess(address _testAddress) public {
        vm.assume(_testAddress != address(0xDEAD));
        vm.prank(_testAddress);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddress).withdrawExcess();
    }

    function testRevertNoExcessToWithdraw(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        vm.assume(_depositAmount <= underlyingDealTokenTotal);
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(_depositAmount);
        vm.expectRevert("no excess to withdraw");
        AelinUpFrontDeal(dealAddress).withdrawExcess();
        vm.stopPrank();
    }

    function testWithdrawExcess(uint256 _depositAmount) public {
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        vm.assume(_depositAmount > underlyingDealTokenTotal);
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
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
                              acceptDeal
    //////////////////////////////////////////////////////////////*/

    function testRevertAcceptDealBeforeDeposit(address _user, uint256 _purchaseAmount) public {
        vm.prank(_user);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.expectRevert("deal token not deposited");
        AelinUpFrontDeal(dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
    }

    function testRevertAcceptDealNotInPurchaseWindow(address _user, uint256 _purchaseAmount) public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        // deposit to start purchase period
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddress), type(uint256).max);
        (uint256 underlyingDealTokenTotal, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        AelinUpFrontDeal(dealAddress).depositUnderlyingTokens(underlyingDealTokenTotal);
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), block.timestamp + 10 days + 60 days);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), block.timestamp + 10 days + 60 days + 365 days);
        vm.stopPrank();
        // warp past purchase period and try to accept deal
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddress).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.startPrank(_user);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();

        // try on a contract that was deposited during intialize
        vm.startPrank(_user);
        purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        vm.expectRevert("not in purchase window");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNotEnoughTokens() public {
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.prank(address(0x1337));
        deal(address(purchaseToken), address(0xDEAD), 100);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectRevert("not enough purchaseToken");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, 2000);
    }

    function testAcceptDealBasic(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 0);
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        vm.assume(_purchaseAmount <= underlyingDealTokenTotal);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        address user = address(0x456);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(user), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(user), _purchaseAmount);
        vm.stopPrank();
    }

    function testAcceptDealMultiplePurchasers() public {
        address _user1 = address(0x1337);
        address _user2 = address(0x1338);
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 _purchaseAmount = 1e34;
        vm.assume(_purchaseAmount <= underlyingDealTokenTotal);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        require(poolSharesAmount > 0, "purchase amount too small");
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), _user1, type(uint256).max);
        deal(address(purchaseToken), _user2, type(uint256).max);
        vm.prank(_user1);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.prank(_user2);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        uint256 totalPurchaseTransactions = underlyingDealTokenTotal / _purchaseAmount;
        for (uint256 i; i < totalPurchaseTransactions; ++i) {
            address user;
            if (i % 2 == 0) {
                user = _user1;
            } else {
                user = _user2;
            }
            vm.startPrank(user);
            uint256 usersPurchaseTokens = AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(user);
            uint256 usersPoolShares = AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(user);
            vm.expectEmit(true, false, false, true);
            emit AcceptDeal(
                user,
                _purchaseAmount,
                usersPurchaseTokens + _purchaseAmount,
                poolSharesAmount,
                usersPoolShares + poolSharesAmount
            );
            AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
            assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount * (i + 1));
            assertEq(
                AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(user),
                usersPoolShares + poolSharesAmount
            );
            assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount * (i + 1));
            assertEq(
                AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(user),
                usersPurchaseTokens + _purchaseAmount
            );
            vm.stopPrank();
        }
    }

    function testAcceptDealRevertOverTotal() public {
        address user1 = address(0x1337);
        address user2 = address(0x1338);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        uint256 purchaseAmount1 = 1e34;
        uint256 purchaseAmount2 = 1e37;
        uint256 poolSharesAmount1 = (purchaseAmount1 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        uint256 poolSharesAmount2 = (purchaseAmount2 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        require(poolSharesAmount1 > 0, "purchase amount too small");
        require(poolSharesAmount2 > 0, "purchase amount too small");
        vm.assume(poolSharesAmount1 > 0);
        vm.assume(poolSharesAmount2 > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), user1, type(uint256).max);
        deal(address(purchaseToken), user2, type(uint256).max);
        vm.prank(user1);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.prank(user2);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        // user1 acceptDeal
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount1, purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount1);
        // user2 acceptDeal
        vm.prank(user2);
        vm.expectRevert("purchased amount > total");
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2);
    }

    function testAcceptDealAllowDeallocation() public {
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        // purchase
        address user1 = address(0x1337);
        vm.startPrank(user1);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        uint256 purchaseAmount1 = 6e35;
        uint256 poolSharesAmount1 = (purchaseAmount1 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        require(poolSharesAmount1 > 0, "purchase amount too small");
        require(poolSharesAmount1 > underlyingDealTokenTotal, "pool shares lower than total");
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), user1, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(user1, purchaseAmount1, purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);
        assertTrue(poolSharesAmount1 > underlyingDealTokenTotal);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(user1), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(user1), purchaseAmount1);
        vm.stopPrank();
    }

    function testAcceptDealNotInAllowList(address _user, uint256 _purchaseAmount) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(0x1337));
        vm.assume(_user != address(0xBEEF));
        vm.assume(_user != address(0xDEED));
        vm.startPrank(_user);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowList
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        uint256 purchaseAmount1 = 1e34;
        uint256 poolSharesAmount1 = (purchaseAmount1 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        require(poolSharesAmount1 > 0, "purchase amount too small");
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testAcceptDealAllowList(
        uint256 _purchaseAmount1,
        uint256 _purchaseAmount2,
        uint256 _purchaseAmount3
    ) public {
        vm.assume(_purchaseAmount1 <= 1e18);
        vm.assume(_purchaseAmount2 <= 2e18);
        vm.assume(_purchaseAmount3 <= 3e18);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        uint256 poolSharesAmount1 = (_purchaseAmount1 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount1 > 0);
        uint256 poolSharesAmount2 = (_purchaseAmount2 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount2 > 0);
        uint256 poolSharesAmount3 = (_purchaseAmount3 * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount3 > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        // user1
        vm.startPrank(address(0x1337));
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount1, _purchaseAmount1, poolSharesAmount1, poolSharesAmount1);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPoolSharesPerUser(address(0x1337)), poolSharesAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount1);
        vm.stopPrank();
        // user2
        vm.startPrank(address(0xBEEF));
        deal(address(purchaseToken), address(0xBEEF), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0xBEEF), _purchaseAmount2, _purchaseAmount2, poolSharesAmount2, poolSharesAmount2);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(), poolSharesAmount1 + poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPoolSharesPerUser(address(0xBEEF)), poolSharesAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(), _purchaseAmount1 + _purchaseAmount2);
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPurchaseTokensPerUser(address(0xBEEF)), _purchaseAmount2);
        vm.stopPrank();
        // user3
        vm.startPrank(address(0xDEED));
        deal(address(purchaseToken), address(0xDEED), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0xDEED), _purchaseAmount3, _purchaseAmount3, poolSharesAmount3, poolSharesAmount3);
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPoolShares(),
            poolSharesAmount1 + poolSharesAmount2 + poolSharesAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPoolSharesPerUser(address(0xDEED)), poolSharesAmount3);
        assertEq(
            AelinUpFrontDeal(dealAddressAllowList).totalPurchasingAccepted(),
            _purchaseAmount1 + _purchaseAmount2 + _purchaseAmount3
        );
        assertEq(AelinUpFrontDeal(dealAddressAllowList).getPurchaseTokensPerUser(address(0xDEED)), _purchaseAmount3);
        vm.stopPrank();
    }

    function testAcceptDealOverAllowList(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount > 1e18);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        vm.startPrank(address(0x1337));
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("more than allocation");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNoNftList() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e18;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowList), type(uint256).max);
        vm.expectRevert("pool does not have an NFT list");
        AelinUpFrontDeal(dealAddressAllowList).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealNftCollectionNotSupported() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e18;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("collection not in the pool");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    function testAcceptDealERC721(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount <= 1e20 + 1e20 + 1e22);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        nftPurchaseList[1].collectionAddress = address(collectionAddress2);
        nftPurchaseList[1].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress1).mint(address(0x1337), 1);
        MockERC721(collectionAddress1).mint(address(0x1337), 2);
        MockERC721(collectionAddress2).mint(address(0x1337), 1);
        MockERC721(collectionAddress2).mint(address(0x1337), 2);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        bool walletClaimed;
        bool NftIdUsed;
        bool hasNftList;
        // checks before purchase
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            address(0x1337),
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            address(0x1337),
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            address(0x1337),
            1
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            address(0x1337),
            2
        );
        assertFalse(walletClaimed);
        assertFalse(NftIdUsed);
        assertTrue(hasNftList);
        // purchase
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        // checks after purchase
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            address(0x1337),
            1
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress1),
            address(0x1337),
            2
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            address(0x1337),
            1
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
        (walletClaimed, NftIdUsed, hasNftList) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(
            address(collectionAddress2),
            address(0x1337),
            2
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        assertTrue(hasNftList);
    }

    function testRevertAcceptDealMustBeOwner() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e20 + 1e20 + 1e22;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        nftPurchaseList[1].collectionAddress = address(collectionAddress2);
        nftPurchaseList[1].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress1).mint(address(0x1337), 1);
        MockERC721(collectionAddress1).mint(address(0x1338), 2);
        MockERC721(collectionAddress2).mint(address(0x1337), 1);
        MockERC721(collectionAddress2).mint(address(0x1337), 2);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("has to be the token owner");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
    }

    function testRevertAcceptDealERC721AlreadyUsed() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e20 + 1e20 + 1e22;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        nftPurchaseList[1].collectionAddress = address(collectionAddress2);
        nftPurchaseList[1].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress1).mint(address(0x1337), 1);
        MockERC721(collectionAddress1).mint(address(0x1337), 2);
        MockERC721(collectionAddress2).mint(address(0x1337), 1);
        MockERC721(collectionAddress2).mint(address(0x1337), 2);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.expectRevert("tokenId already used");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
    }

    function testRevertAcceptDealERC721WalletAlreadyUsed() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e22;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](1);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress2);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress2).mint(address(0x1337), 1);
        MockERC721(collectionAddress2).mint(address(0x1337), 2);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), purchaseAmount, purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.expectRevert("wallet already used for nft set");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
    }

    function testRevertAcceptDealERC721OverAllowed() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e20 + 1e20 + 1e22 + 1;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressAllowList).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray = new uint256[](2);
        tokenIdsArray[0] = 1;
        tokenIdsArray[1] = 2;
        nftPurchaseList[0].collectionAddress = address(collectionAddress1);
        nftPurchaseList[0].tokenIds = tokenIdsArray;
        nftPurchaseList[1].collectionAddress = address(collectionAddress2);
        nftPurchaseList[1].tokenIds = tokenIdsArray;
        MockERC721(collectionAddress1).mint(address(0x1337), 1);
        MockERC721(collectionAddress1).mint(address(0x1337), 2);
        MockERC721(collectionAddress2).mint(address(0x1337), 1);
        MockERC721(collectionAddress2).mint(address(0x1337), 2);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating721), type(uint256).max);
        vm.expectRevert("purchase amount greater than max allocation");
        AelinUpFrontDeal(dealAddressNftGating721).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    // TO DO
    // function testAcceptDealPunks() public {}

    function testAcceptDealERC1155(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount <= 1e20 * 11 + 1e22);
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressNftGating1155
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray1 = new uint256[](1);
        uint256[] memory tokenIdsArray2 = new uint256[](1);
        tokenIdsArray1[0] = 1;
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray1;
        tokenIdsArray2[0] = 10;
        nftPurchaseList[1].collectionAddress = address(collectionAddress5);
        nftPurchaseList[1].tokenIds = tokenIdsArray2;
        bytes memory data = bytes("0");
        MockERC1155(collectionAddress4).mint(address(0x1337), 1, 11, data);
        MockERC1155(collectionAddress5).mint(address(0x1337), 10, 1000, data);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        bool walletClaimed;
        bool NftIdUsed;
        // checks before purchase
        (walletClaimed, NftIdUsed, ) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress4),
            address(0x1337),
            1
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        (walletClaimed, NftIdUsed, ) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress5),
            address(0x1337),
            10
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        // purchase
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        // checks after purchase
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        (walletClaimed, NftIdUsed, ) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress4),
            address(0x1337),
            1
        );
        assertFalse(walletClaimed);
        assertTrue(NftIdUsed);
        (walletClaimed, NftIdUsed, ) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(
            address(collectionAddress5),
            address(0x1337),
            10
        );
        assertTrue(walletClaimed);
        assertTrue(NftIdUsed);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC1155NotInPool() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e20 * 11 + 1e22;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray1 = new uint256[](1);
        uint256[] memory tokenIdsArray2 = new uint256[](1);
        tokenIdsArray1[0] = 80;
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray1;
        tokenIdsArray2[0] = 10;
        nftPurchaseList[1].collectionAddress = address(collectionAddress5);
        nftPurchaseList[1].tokenIds = tokenIdsArray2;
        bytes memory data = bytes("0");
        MockERC1155(collectionAddress4).mint(address(0x1337), 1, 11, data);
        MockERC1155(collectionAddress5).mint(address(0x1337), 10, 1000, data);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        vm.expectRevert("tokenId not in the pool");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    function testRevertAcceptDealERC1155BalanceTooLow() public {
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount = 1e20 * 11 + 1e22;
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressNftGating1155).dealConfig();
        (bool success, ) = SafeMath.tryMul(purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList = new AelinNftGating.NftPurchaseList[](2);
        uint256[] memory tokenIdsArray1 = new uint256[](1);
        uint256[] memory tokenIdsArray2 = new uint256[](1);
        tokenIdsArray1[0] = 1;
        nftPurchaseList[0].collectionAddress = address(collectionAddress4);
        nftPurchaseList[0].tokenIds = tokenIdsArray1;
        tokenIdsArray2[0] = 10;
        nftPurchaseList[1].collectionAddress = address(collectionAddress5);
        nftPurchaseList[1].tokenIds = tokenIdsArray2;
        bytes memory data = bytes("0");
        MockERC1155(collectionAddress4).mint(address(0x1337), 1, 9, data);
        MockERC1155(collectionAddress5).mint(address(0x1337), 10, 1000, data);
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        vm.expectRevert("erc1155 balance too low");
        AelinUpFrontDeal(dealAddressNftGating1155).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            purchaserClaim
    //////////////////////////////////////////////////////////////*/

    function testRevertPurchaserClaimNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).purchaserClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        vm.stopPrank();
    }

    function testRevertPurchaserClaimNoShares(address _user) public {
        vm.assume(_user != address(0));
        vm.startPrank(_user);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("no pool shares to claim with");
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        vm.stopPrank();
    }

    // Does not meet purchaseRaiseMinimum
    function testPurchaserClaimRefund(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount < 1e28);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        // claim attempt
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), 0, _purchaseAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), 0);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max);
    }

    function testPurchaserClaimNoDeallocation(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount > 1e28);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), 0);
        // claim
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        uint256 poolSharesPerUser = AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337));
        uint256 adjustedDealTokensForUser = ((BASE - AELIN_FEE - sponsorFee) * poolSharesPerUser) / BASE;
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), adjustedDealTokensForUser, 0);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), 0);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), 0);
    }

    function testPurchaserClaimWithDeallocation() public {
        uint256 _purchaseAmount = 6e35;
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e36);
        vm.stopPrank();
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        assertEq(MockERC20(dealAddressAllowDeallocation).balanceOf(address(0x1337)), 0);
        // claim
        uint256 adjustedDealTokensForUser = (((AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(
            address(0x1337)
        ) * underlyingDealTokenTotal) / AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares()) *
            (BASE - AELIN_FEE - sponsorFee)) / BASE;
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        uint256 purchasingRefund = AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)) -
            ((AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)) *
                totalIntendedRaise) / AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted());
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.warp(AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry() + 1 days);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), adjustedDealTokensForUser, purchasingRefund);
        AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim();
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)), 0);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount + purchasingRefund);
        assertEq(MockERC20(dealAddressAllowDeallocation).balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            sponsorClaim
    //////////////////////////////////////////////////////////////*/

    function testRevertSponsorClaimNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).sponsorClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimFailMinimumRaise(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount < 1e28);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        vm.stopPrank();
        // attempt claim
        vm.startPrank(address(0xBEEF));
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimNotSponsor(uint256 _purchaseAmount, address _address) public {
        vm.assume(_address != address(0));
        vm.assume(_address != address(0xBEEF));
        vm.assume(_address != address(dealAddressOverFullDeposit));
        vm.startPrank(_address);
        vm.assume(_purchaseAmount > 10e28);
        vm.assume(_purchaseAmount < 1e35);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), _address, type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(_address, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(_address), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(_address), _purchaseAmount);
        // attempt claim
        assertEq(purchaseToken.balanceOf(_address), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("must be sponsor");
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        vm.stopPrank();
    }

    function testRevertSponsorClaimAlreadyClaimed() public {
        vm.startPrank(address(0x1337));
        uint256 _purchaseAmount = 6e28;
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xBEEF));
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint256 totalSold = AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares();
        uint256 amountMinted = (totalSold * sponsorFee) / BASE;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(address(0xBEEF), amountMinted);
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        // claim again
        vm.expectRevert("sponsor already claimed");
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        vm.stopPrank();
    }

    function testSponsorClaimNoDeallocation(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount > 3e28);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xBEEF));
        assertEq(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()), address(0));
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint256 totalSold = AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares();
        uint256 amountMinted = (totalSold * sponsorFee) / BASE;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(address(0xBEEF), amountMinted);
        AelinUpFrontDeal(dealAddressOverFullDeposit).sponsorClaim();
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0xBEEF)), amountMinted);
        uint256 feeAmount = (totalSold * AELIN_FEE) / BASE;
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    function testSponsorClaimWithDeallocation() public {
        uint256 _purchaseAmount = 6e35;
        vm.assume(_purchaseAmount > 3e28);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xBEEF));
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        uint256 amountMinted = (underlyingDealTokenTotal * sponsorFee) / BASE;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit SponsorClaim(address(0xBEEF), amountMinted);
        AelinUpFrontDeal(dealAddressAllowDeallocation).sponsorClaim();
        assertEq(MockERC20(dealAddressAllowDeallocation).balanceOf(address(0xBEEF)), amountMinted);
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            holderClaim
    //////////////////////////////////////////////////////////////*/

    function testRevertHolderClaimNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).holderClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        vm.stopPrank();
    }

    function testRevertHolderClaimNotHolder(address _address, uint256 _purchaseAmount) public {
        vm.assume(_address != address(0));
        vm.assume(_address != address(0xDEAD));
        vm.assume(_address != address(dealAddressOverFullDeposit));
        vm.startPrank(_address);
        vm.assume(_purchaseAmount > 6e28);
        vm.assume(_purchaseAmount < 1e35);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), _address, type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(_address, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(_address), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(_address), _purchaseAmount);
        // attempt claim
        assertEq(purchaseToken.balanceOf(_address), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("must be holder");
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        vm.stopPrank();
    }

    function testRevertHolderClaimAlreadyClaimed() public {
        vm.startPrank(address(0x1337));
        uint256 _purchaseAmount = 6e28;
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xDEAD));
        uint256 amountRaise = purchaseToken.balanceOf(dealAddressOverFullDeposit);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xDEAD),
            address(purchaseToken),
            amountRaise,
            address(underlyingDealToken),
            underlyingDealTokenTotal - poolSharesAmount,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        // claim again
        vm.expectRevert("holder already claimed");
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        vm.stopPrank();
    }

    function testHolderClaimFailMinimumRaise(uint256 _purchaseAmount) public {
        vm.assume(_purchaseAmount < 1e28);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        vm.stopPrank();
        // attempt claim
        vm.startPrank(address(0xDEAD));
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        uint256 amountRefund = underlyingDealToken.balanceOf(address(dealAddressOverFullDeposit));
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(address(0xDEAD));
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xDEAD),
            address(purchaseToken),
            0,
            address(underlyingDealToken),
            amountRefund,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        uint256 amountAfterClaim = underlyingDealToken.balanceOf(address(0xDEAD));
        assertEq(amountAfterClaim - amountBeforeClaim, amountRefund);
        vm.stopPrank();
    }

    function testHolderClaimNoDeallocation() public {
        vm.startPrank(address(0x1337));
        uint256 _purchaseAmount = 6e28;
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xDEAD));
        uint256 amountRaise = purchaseToken.balanceOf(dealAddressOverFullDeposit);
        uint256 amountRefund = underlyingDealTokenTotal - AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares();
        uint256 amountBeforeClaim = underlyingDealToken.balanceOf(address(0xDEAD));
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xDEAD),
            address(purchaseToken),
            amountRaise,
            address(underlyingDealToken),
            underlyingDealTokenTotal - poolSharesAmount,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressOverFullDeposit).holderClaim();
        uint256 amountAfterClaim = underlyingDealToken.balanceOf(address(0xDEAD));
        assertEq(amountAfterClaim - amountBeforeClaim, amountRefund);
        uint256 totalSold = AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares();
        assertEq(purchaseToken.balanceOf(address(0xDEAD)), amountRaise);
        uint256 feeAmount = (totalSold * AELIN_FEE) / BASE;
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow())),
            feeAmount
        );
    }

    function testHolderClaimWithDeallocation() public {
        uint256 _purchaseAmount = 6e35;
        vm.assume(_purchaseAmount > 3e28);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(address(0xDEAD));
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xDEAD),
            address(purchaseToken),
            totalIntendedRaise,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        assertEq(purchaseToken.balanceOf(address(0xDEAD)), totalIntendedRaise);
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            feeEscrowClaim
    //////////////////////////////////////////////////////////////*/

    function testRevertEscrowClaimNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).feeEscrowClaim();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).feeEscrowClaim();
        vm.stopPrank();
    }

    function testEscrowClaimNoDeallocation(address _address) public {
        vm.startPrank(address(0x1337));
        uint256 _purchaseAmount = 6e28;
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(_address);
        assertEq(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()), address(0));
        uint256 totalSold = AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares();
        uint256 feeAmount = (totalSold * AELIN_FEE) / BASE;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).feeEscrowClaim();
        assertTrue(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()) != address(0));
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow())),
            feeAmount
        );
    }

    function testEscrowClaimWithDeallocation(address _address) public {
        uint256 _purchaseAmount = 6e35;
        vm.assume(_purchaseAmount > 3e28);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount > underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        vm.stopPrank();
        // claim
        vm.startPrank(_address);
        assertEq(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()), address(0));
        uint256 feeAmount = (underlyingDealTokenTotal * AELIN_FEE) / BASE;
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressAllowDeallocation).feeEscrowClaim();
        assertTrue(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow()) != address(0));
        assertEq(
            underlyingDealToken.balanceOf(address(AelinUpFrontDeal(dealAddressAllowDeallocation).aelinFeeEscrow())),
            feeAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                        claimableUnderlyingTokens
    //////////////////////////////////////////////////////////////*/

    function testRevertClaimableUnderlyingNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).claimableUnderlyingTokens(address(0x1337));
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(address(0x1337));
        vm.stopPrank();
    }

    function testClaimableUnderlyingQuantityZero(address _address, uint256 _timeAfterPurchasing) public {
        vm.assume(_address != address(0));
        vm.assume(_address != address(0x1337));
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        assertEq(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()), address(0));
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claimable underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        uint256 claimable = AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(_address);
        assertEq(claimable, 0);
        vm.stopPrank();
    }

    function testClaimableUnderlying(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        assertEq(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()), address(0));
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claimable underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        (, , , , uint256 vestingPeriod, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        uint256 underlyingClaimable;
        uint256 maxTime = block.timestamp > AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry()
            ? AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry()
            : block.timestamp;
        if (
            MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)) > 0 &&
            (maxTime > AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry() ||
                (maxTime == AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry() && vestingPeriod == 0))
        ) {
            uint256 timeElapsed = maxTime - AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry();

            underlyingClaimable = vestingPeriod == 0
                ? MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337))
                : ((MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)) +
                    AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337))) * timeElapsed) /
                    vestingPeriod -
                    AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337));
        }

        uint256 claimable = AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(address(0x1337));
        assertEq(claimable, underlyingClaimable);
        vm.stopPrank();
    }

    function testClaimableUnderlyingDuringVestingCliff(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry();
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing > purchaseExpiry);
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing <= vestingCliffExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claimable underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        uint256 claimable = AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(address(0x1337));
        assertEq(claimable, 0);
        vm.stopPrank();
    }

    function testClaimableUnderlyingAfterVesting(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry();
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing > vestingExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claimable underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        uint256 claimable = AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(address(0x1337));
        assertEq(claimable, MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)));
        vm.stopPrank();
    }

    function testClaimableUnderlyingDuringVest(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry();
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry();
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing > vestingCliffExpiry);
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing < vestingExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claimable underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        (, , , , uint256 vestingPeriod, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        uint256 timeElapsed = maxTime - AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry();
        uint256 expectedClaim = ((MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)) +
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337))) * timeElapsed) /
            vestingPeriod -
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337));
        uint256 claimable = AelinUpFrontDeal(dealAddressOverFullDeposit).claimableUnderlyingTokens(address(0x1337));
        assertEq(claimable, expectedClaim);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            claimUnderlying
    //////////////////////////////////////////////////////////////*/

    function testRevertClaimNotInWindow() public {
        vm.startPrank(address(0x1337));
        vm.expectRevert("underlying deposit incomplete");
        AelinUpFrontDeal(dealAddress).claimUnderlying();
        vm.expectRevert("purchase period not over");
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        vm.stopPrank();
    }

    function testRevertClaimFailMinimumRaise(uint256 _purchaseAmount) public {
        vm.startPrank(address(0x1337));
        vm.assume(_purchaseAmount < 1e28);
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        // claim attempt
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        vm.expectRevert("does not pass min raise");
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        vm.stopPrank();
    }

    function testClaimQuantityZero(address _address, uint256 _timeAfterPurchasing) public {
        vm.assume(_address != address(0));
        vm.assume(_address != address(0x1337));
        vm.assume(_address != address(0xDEAD));
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        assertEq(address(AelinUpFrontDeal(dealAddressOverFullDeposit).aelinFeeEscrow()), address(0));
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        vm.stopPrank();
        // claim underlying
        vm.startPrank(_address);
        vm.expectRevert("no underlying ready to claim");
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        vm.stopPrank();
    }

    function testClaimDuringVestingCliff(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingCliffExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry();
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing > purchaseExpiry);
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing <= vestingCliffExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claim underlying
        vm.expectRevert("no underlying ready to claim");
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        vm.stopPrank();
    }

    function testClaimAfterVesting(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry();
        vm.assume(purchaseExpiry + 1 days + _timeAfterPurchasing > vestingExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        uint256 adjustedDealTokensForUser = ((BASE - AELIN_FEE - sponsorFee) *
            AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337))) / BASE;
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claim underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337)), 0);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalUnderlyingClaimed(), 0);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(address(0x1337), address(underlyingDealToken), adjustedDealTokensForUser);
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        // after claim checks
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337)), adjustedDealTokensForUser);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), 0);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalUnderlyingClaimed(), adjustedDealTokensForUser);
        vm.stopPrank();
    }

    function testClaimDuringVest(uint256 _timeAfterPurchasing) public {
        vm.assume(_timeAfterPurchasing < 2190 days);
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        uint256 _purchaseAmount = 6e28;
        // ensure right window
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        uint256 vestingExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).vestingExpiry();
        vm.assume(
            purchaseExpiry + 1 days + _timeAfterPurchasing >
                AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry()
        );
        vm.assume(purchaseExpiry + 1 days + 2 days + _timeAfterPurchasing < vestingExpiry);
        // accept deal
        vm.startPrank(address(0x1337));
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        vm.assume((_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken > 0);
        vm.assume((_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(
            AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(),
            (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken
        );
        assertEq(
            AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)),
            (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken
        );
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        // claim
        vm.warp(purchaseExpiry + 1 days);
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        uint256 adjustedDealTokensForUser = ((BASE - AELIN_FEE - sponsorFee) *
            AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337))) / BASE;
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        // claim underlying
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing);
        (, , , , uint256 vestingPeriod, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealConfig();
        uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        uint256 expectedClaim1 = ((MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)) +
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337))) *
            (maxTime - AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry())) /
            vestingPeriod -
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337));
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337)), 0);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalUnderlyingClaimed(), 0);
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(address(0x1337), address(underlyingDealToken), expectedClaim1);
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        // after claim checks
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337)), expectedClaim1);
        assertEq(
            MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)),
            adjustedDealTokensForUser - expectedClaim1
        );
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), expectedClaim1);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalUnderlyingClaimed(), expectedClaim1);

        // wait some time and claim again
        vm.warp(purchaseExpiry + 1 days + _timeAfterPurchasing + 2 days);
        maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        uint256 expectedClaim2 = ((MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)) +
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337))) *
            (maxTime - AelinUpFrontDeal(dealAddressOverFullDeposit).vestingCliffExpiry())) /
            vestingPeriod -
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337));
        vm.expectEmit(true, false, false, true);
        emit ClaimedUnderlyingDealToken(address(0x1337), address(underlyingDealToken), expectedClaim2);
        AelinUpFrontDeal(dealAddressOverFullDeposit).claimUnderlying();
        // after claim checks
        assertEq(
            AelinUpFrontDeal(dealAddressOverFullDeposit).getAmountVested(address(0x1337)),
            expectedClaim1 + expectedClaim2
        );
        assertEq(
            MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)),
            adjustedDealTokensForUser - expectedClaim1 - expectedClaim2
        );
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), expectedClaim1 + expectedClaim2);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalUnderlyingClaimed(), expectedClaim1 + expectedClaim2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        Deal Token Transfers Blocked
    //////////////////////////////////////////////////////////////*/

    function testDealTokenTransferBlocked() public {
        vm.startPrank(address(0x1337));
        uint256 _purchaseAmount = 1e29;
        // accept deal
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressOverFullDeposit
        ).dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(dealAddressOverFullDeposit), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit AcceptDeal(address(0x1337), _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
        AelinUpFrontDeal(dealAddressOverFullDeposit).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPoolShares(), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), poolSharesAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), _purchaseAmount);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), 0);
        // claim
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressOverFullDeposit).purchaseExpiry();
        vm.warp(purchaseExpiry + 1 days);
        (, , , , , , uint256 sponsorFee, , ) = AelinUpFrontDeal(dealAddressOverFullDeposit).dealData();
        uint256 poolSharesPerUser = AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337));
        uint256 adjustedDealTokensForUser = ((BASE - AELIN_FEE - sponsorFee) * poolSharesPerUser) / BASE;
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), adjustedDealTokensForUser, 0);
        AelinUpFrontDeal(dealAddressOverFullDeposit).purchaserClaim();
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPoolSharesPerUser(address(0x1337)), 0);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).totalPurchasingAccepted(), _purchaseAmount);
        assertEq(AelinUpFrontDeal(dealAddressOverFullDeposit).getPurchaseTokensPerUser(address(0x1337)), 0);
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - _purchaseAmount);
        assertEq(MockERC20(dealAddressOverFullDeposit).balanceOf(address(0x1337)), adjustedDealTokensForUser);
        assertEq(underlyingDealToken.balanceOf(address(0x1337)), 0);
        // attempt deal token transfers
        vm.expectRevert("cant transfer deal tokens");
        MockERC20(dealAddressOverFullDeposit).transfer(address(0x1111), 1);
        vm.expectRevert("cant transfer deal tokens");
        MockERC20(dealAddressOverFullDeposit).transferFrom(address(0x1337), address(0x1111), 1);
        vm.stopPrank();
    }

    // /*//////////////////////////////////////////////////////////////
    //                  Scenarios with precision error
    // //////////////////////////////////////////////////////////////*/

    function testScenarioWithPrecisionErrorPurchaserSide() public {
        // Deal config
        vm.startPrank(address(0xDEED));
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xBAAF),
            sponsor: address(0xDEED),
            sponsorFee: 0,
            ipfsHash: 0,
            merkleRoot: 0
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1.5e18,
            purchaseTokenPerDealToken: 2e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 1 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: true
        });

        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            upfrontDealAddress
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        // Deal funding
        vm.stopPrank();
        vm.startPrank(address(0xBAAF));
        deal(address(underlyingDealToken), address(0xBAAF), type(uint256).max);
        underlyingDealToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).depositUnderlyingTokens(1.5e18);

        // Deal acceptance: 31 purchaseTokens in total between 3 wallets for a 3 purchaseTokens deal in total.
        // Deallocation could lead to precision errors
        vm.stopPrank();
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount1 = 1e18;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);

        vm.stopPrank();
        vm.startPrank(address(0x1338));
        uint256 purchaseAmount2 = 10e18;
        deal(address(purchaseToken), address(0x1338), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2);

        vm.stopPrank();
        vm.startPrank(address(0x1339));
        uint256 purchaseAmount3 = 20e18;
        deal(address(purchaseToken), address(0x1339), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount3);

        //HolderClaim
        vm.stopPrank();
        vm.startPrank(address(0xBAAF));
        vm.warp(AelinUpFrontDeal(upfrontDealAddress).purchaseExpiry() + 1 days);
        assertEq(purchaseToken.balanceOf(address(0xBAAF)), 0);
        AelinUpFrontDeal(upfrontDealAddress).holderClaim();

        //Holder is likely to have accepted more than what the wallets will invest once the deallocation occurs
        assertEq(
            purchaseToken.balanceOf(address(0xBAAF)),
            (underlyingDealTokenTotal * purchaseTokenPerDealToken) / 10**underlyingTokenDecimals
        );

        // PurchaserClaim 1
        vm.stopPrank();
        vm.startPrank(address(0x1337));

        uint256 adjustedDealTokensForUser = (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1337)) *
            underlyingDealTokenTotal) / AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) / BASE;

        uint256 purchasingRefund = AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1337)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1337)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - purchaseAmount1);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), adjustedDealTokensForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();

        // First purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - purchaseAmount1 + purchasingRefund);

        // PurchaserClaim 2
        vm.stopPrank();
        vm.startPrank(address(0x1338));

        adjustedDealTokensForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1338)) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1338)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1338)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1338)), type(uint256).max - purchaseAmount2);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1338), adjustedDealTokensForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();

        // Second purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(address(0x1338)), type(uint256).max - purchaseAmount2 + purchasingRefund);

        // PurchaserClaim 3
        vm.stopPrank();
        vm.startPrank(address(0x1339));

        adjustedDealTokensForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1339)) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1339)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1339)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3);

        // Due to precision error, there is not enough purchaseTokens in the contract to refund the last wallet
        // So the refund amount for the last wallet equals the contract's balance
        uint256 contractRemainingBalance = purchaseToken.balanceOf(upfrontDealAddress);
        assertGt(purchasingRefund, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1339), adjustedDealTokensForUser, contractRemainingBalance);
        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();
        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3 + contractRemainingBalance);
    }

    function testScenarioWithPrecisionErrorHolderSide() public {
        // Deal config
        vm.startPrank(address(0xDEED));
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinAllowList.InitData memory allowListInitEmpty;

        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xBAAF),
            sponsor: address(0xDEED),
            sponsorFee: 0,
            ipfsHash: 0,
            merkleRoot: 0
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1.5e18,
            purchaseTokenPerDealToken: 2e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 1 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: true
        });

        address upfrontDealAddress = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );

        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            upfrontDealAddress
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        uint256 totalIntendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        // Deal funding
        vm.stopPrank();
        vm.startPrank(address(0xBAAF));
        deal(address(underlyingDealToken), address(0xBAAF), type(uint256).max);
        underlyingDealToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).depositUnderlyingTokens(1.5e18);

        // Deal acceptance: 31 purchaseTokens in total between 3 wallets for a 3 purchaseTokens deal in total.
        // Deallocation could lead to precision errors
        vm.stopPrank();
        vm.startPrank(address(0x1337));
        uint256 purchaseAmount1 = 1e18;
        deal(address(purchaseToken), address(0x1337), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount1);

        vm.stopPrank();
        vm.startPrank(address(0x1338));
        uint256 purchaseAmount2 = 10e18;
        deal(address(purchaseToken), address(0x1338), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount2);

        vm.stopPrank();
        vm.startPrank(address(0x1339));
        uint256 purchaseAmount3 = 20e18;
        deal(address(purchaseToken), address(0x1339), type(uint256).max);
        purchaseToken.approve(address(upfrontDealAddress), type(uint256).max);
        AelinUpFrontDeal(upfrontDealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, purchaseAmount3);

        vm.warp(AelinUpFrontDeal(upfrontDealAddress).purchaseExpiry() + 1 days);

        // PurchaserClaim 1
        vm.stopPrank();
        vm.startPrank(address(0x1337));

        uint256 adjustedDealTokensForUser = (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1337)) *
            underlyingDealTokenTotal) / AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) / BASE;

        uint256 purchasingRefund = AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1337)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1337)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - purchaseAmount1);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1337), adjustedDealTokensForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();

        // First purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(address(0x1337)), type(uint256).max - purchaseAmount1 + purchasingRefund);

        // PurchaserClaim 2
        vm.stopPrank();
        vm.startPrank(address(0x1338));

        adjustedDealTokensForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1338)) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1338)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1338)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1338)), type(uint256).max - purchaseAmount2);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1338), adjustedDealTokensForUser, purchasingRefund);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();

        // Second purchaser gets refunded entirely
        assertEq(purchaseToken.balanceOf(address(0x1338)), type(uint256).max - purchaseAmount2 + purchasingRefund);

        // PurchaserClaim 3
        vm.stopPrank();
        vm.startPrank(address(0x1339));

        adjustedDealTokensForUser =
            (((AelinUpFrontDeal(upfrontDealAddress).getPoolSharesPerUser(address(0x1339)) * underlyingDealTokenTotal) /
                AelinUpFrontDeal(upfrontDealAddress).totalPoolShares()) * (BASE - AELIN_FEE)) /
            BASE;

        purchasingRefund =
            AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1339)) -
            ((AelinUpFrontDeal(upfrontDealAddress).getPurchaseTokensPerUser(address(0x1339)) * totalIntendedRaise) /
                AelinUpFrontDeal(upfrontDealAddress).totalPurchasingAccepted());

        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3);
        vm.expectEmit(true, false, false, true);
        emit ClaimDealTokens(address(0x1339), adjustedDealTokensForUser, purchasingRefund);
        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3);
        AelinUpFrontDeal(upfrontDealAddress).purchaserClaim();
        assertEq(purchaseToken.balanceOf(address(0x1339)), type(uint256).max - purchaseAmount3 + purchasingRefund);

        // Holder claim.
        // Since all the purchaser wallets have claimed, the holder
        // will claim the contract's balance instead of the intended raise amount
        vm.stopPrank();
        vm.startPrank(address(0xBAAF));
        assertEq(purchaseToken.balanceOf(address(0xBAAF)), 0);
        uint256 contractRemainingBalance = purchaseToken.balanceOf(upfrontDealAddress);
        uint256 intendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        console.log("intendedRaise test 1", intendedRaise);
        console.log("contractRemainingBalance test 1", contractRemainingBalance);
        assertGt(intendedRaise, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xBAAF),
            address(purchaseToken),
            contractRemainingBalance,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(upfrontDealAddress).holderClaim();
        assertEq(purchaseToken.balanceOf(address(0xBAAF)), contractRemainingBalance);
    }

    // /*//////////////////////////////////////////////////////////////
    //                           largePool
    // //////////////////////////////////////////////////////////////*/

    function testTenThousandUserPool() public {
        // deposit underlying
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        // purchasing
        uint256 totalPurchaseAccepted;
        uint256 totalPoolShares;
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(
            dealAddressAllowDeallocation
        ).dealConfig();
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        vm.fee(1 gwei);
        for (uint256 i = 1; i < 10000; ++i) {
            uint256 _purchaseAmount = 1e34 + i;
            uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
            require(poolSharesAmount > 0, "purchase amount too small");
            vm.assume(poolSharesAmount > 0);
            if (i % 200 == 0) {
                vm.roll(block.number + 1);
            }
            AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
            address user = makeAddr(i);
            deal(address(purchaseToken), user, _purchaseAmount);
            vm.startPrank(user);
            purchaseToken.approve(address(dealAddressAllowDeallocation), _purchaseAmount);
            totalPurchaseAccepted += _purchaseAmount;
            totalPoolShares += poolSharesAmount;
            vm.expectEmit(true, false, false, true);
            emit AcceptDeal(user, _purchaseAmount, _purchaseAmount, poolSharesAmount, poolSharesAmount);
            AelinUpFrontDeal(dealAddressAllowDeallocation).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPoolShares(), totalPoolShares);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPoolSharesPerUser(user), poolSharesAmount);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).totalPurchasingAccepted(), totalPurchaseAccepted);
            assertEq(AelinUpFrontDeal(dealAddressAllowDeallocation).getPurchaseTokensPerUser(user), _purchaseAmount);
            vm.stopPrank();
        }
        uint256 purchaseExpiry = AelinUpFrontDeal(dealAddressAllowDeallocation).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        for (uint256 i = 1; i < 10000; ++i) {
            if (i % 200 == 0) {
                vm.roll(block.number + 1);
            }
            address user = makeAddr(i);
            vm.startPrank(user);
            AelinUpFrontDeal(dealAddressAllowDeallocation).purchaserClaim();
            vm.stopPrank();
        }
        vm.startPrank(address(0xDEAD));
        assertEq(purchaseToken.balanceOf(address(0xDEAD)), 0);
        uint256 contractRemainingBalance = purchaseToken.balanceOf(dealAddressAllowDeallocation);
        uint256 intendedRaise = (purchaseTokenPerDealToken * underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        console.log("intendedRaise test 2", intendedRaise);
        console.log("contractRemainingBalance test 2", contractRemainingBalance);
        assertGt(intendedRaise, contractRemainingBalance);
        vm.expectEmit(true, false, false, true);
        emit HolderClaim(
            address(0xDEAD),
            address(purchaseToken),
            contractRemainingBalance,
            address(underlyingDealToken),
            0,
            block.timestamp
        );
        AelinUpFrontDeal(dealAddressAllowDeallocation).holderClaim();
        assertEq(purchaseToken.balanceOf(address(0xDEAD)), contractRemainingBalance);
    }

    // /*//////////////////////////////////////////////////////////////
    //                           merkleTree
    // //////////////////////////////////////////////////////////////*/

    function testNoIpfsHashFailure() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInitEmpty;

        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: 0
        });
        vm.prank(address(0xBEEF));
        vm.expectRevert("merkle needs ipfs hash");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, sharedDealConfig, nftCollectionRulesEmpty, allowListInitEmpty);
    }

    function testNoNftListFailure() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInitEmpty;

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRules721[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules721[0].purchaseAmount = 1e20;
        nftCollectionRules721[0].purchaseAmountPerToken = true;

        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7
        });
        vm.prank(address(0xBEEF));
        vm.expectRevert("cant have nft & merkle");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, sharedDealConfig, nftCollectionRules721, allowListInitEmpty);
    }

    function testNoAllowListFailure() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInit;

        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7
        });
        address[] memory testAllowListAddresses = new address[](1);
        uint256[] memory testAllowListAmounts = new uint256[](1);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAmounts[0] = 1e18;
        allowListInit.allowListAddresses = testAllowListAddresses;
        allowListInit.allowListAmounts = testAllowListAmounts;
        vm.prank(address(0xBEEF));
        vm.expectRevert("cant have allow list & merkle");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, sharedDealConfig, nftCollectionRulesEmpty, allowListInit);
    }

    function testPurchaseAmountTooHighFailure() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        IAelinUpFrontDeal.UpFrontMerkleData memory merkleData;

        merkleData.account = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        merkleData.index = 0;
        merkleData.amount = 100;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0xfa0a69af54d730226f27b04a7fd8ac77312321e142342afe85789c470d98af8b;
        merkleData.merkleProof[1] = 0x08dc84848cfc1b922ae607cc2af96186b9ebad7dbacdac0e1e16498d4d668968;
        bytes32 root = 0x3e6f463625369879b7583baf245a0ac065bd8a9bcb180ecc0ac126d5d71c94bb;
        bytes32 leaf = keccak256(abi.encodePacked(merkleData.index, merkleData.account, merkleData.amount));
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: root,
            ipfsHash: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7
        });
        vm.prank(address(0xBEEF));
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            sharedDealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        vm.expectRevert("purchasing more than allowance");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 101);
    }

    // function testInvalidProofFailure() public {}

    function testNotMessageSenderFailure() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        IAelinUpFrontDeal.UpFrontMerkleData memory merkleData;

        merkleData.account = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        merkleData.index = 0;
        merkleData.amount = 100;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0xfa0a69af54d730226f27b04a7fd8ac77312321e142342afe85789c470d98af8b;
        merkleData.merkleProof[1] = 0x08dc84848cfc1b922ae607cc2af96186b9ebad7dbacdac0e1e16498d4d668968;
        bytes32 root = 0x3e6f463625369879b7583baf245a0ac065bd8a9bcb180ecc0ac126d5d71c94bb;
        bytes32 leaf = keccak256(abi.encodePacked(merkleData.index, merkleData.account, merkleData.amount));
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: root,
            ipfsHash: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7
        });
        vm.prank(address(0xBEEF));
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            sharedDealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(0x456);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        vm.expectRevert("cant purchase others tokens");
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 101);
    }

    // function testAlreadyPurchasedTokensFailure() public {}

    function testMerklePurchaseWorking() public {
        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        IAelinUpFrontDeal.UpFrontMerkleData memory merkleData;
        merkleData.account = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        merkleData.index = 0;
        merkleData.amount = 100;
        // Merkle tree created from ../mocks/merkletree.json
        merkleData.merkleProof = new bytes32[](2);
        merkleData.merkleProof[0] = 0xfa0a69af54d730226f27b04a7fd8ac77312321e142342afe85789c470d98af8b;
        merkleData.merkleProof[1] = 0x08dc84848cfc1b922ae607cc2af96186b9ebad7dbacdac0e1e16498d4d668968;
        bytes32 root = 0x3e6f463625369879b7583baf245a0ac065bd8a9bcb180ecc0ac126d5d71c94bb;
        bytes32 leaf = keccak256(abi.encodePacked(merkleData.index, merkleData.account, merkleData.amount));
        bool test = MerkleProof.verify(merkleData.merkleProof, root, leaf);
        console.log("test", test);
        assertEq(MerkleProof.verify(merkleData.merkleProof, root, leaf), true);
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            merkleRoot: root,
            ipfsHash: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7
        });
        vm.prank(address(0xBEEF));
        address merkleDealAddress = upFrontDealFactory.createUpFrontDeal(
            merkleDealData,
            sharedDealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).depositUnderlyingTokens(1e35);
        vm.stopPrank();
        address user = address(merkleData.account);
        vm.startPrank(user);
        deal(address(purchaseToken), user, type(uint256).max);
        purchaseToken.approve(address(merkleDealAddress), type(uint256).max);
        AelinUpFrontDeal(merkleDealAddress).acceptDeal(nftPurchaseList, merkleData, 100);
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

    event AcceptDeal(
        address indexed user,
        uint256 amountPurchased,
        uint256 totalPurchased,
        uint256 amountDealTokens,
        uint256 totalDealTokens
    );

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

    event ClaimedUnderlyingDealToken(address indexed user, address underlyingToken, uint256 amountClaimed);

    event SetHolder(address indexed holder);

    event Vouch(address indexed voucher);

    event Disavow(address indexed voucher);

    event WithdrewExcess(address UpFrontDealAddress, uint256 amountWithdrawn);

    // creates a labeled address
    function makeAddr(uint256 num) internal returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(num)));
        addr = vm.addr(privateKey);
    }
}
