// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinNftGating} from "contracts/libraries/AelinNftGating.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MerkleTree} from "contracts/libraries/MerkleTree.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AelinUpFrontDealInitTest is Test, AelinTestUtils, IAelinUpFrontDeal {
    AelinUpFrontDeal public testUpFrontDeal;
    AelinFeeEscrow public testEscrow;
    AelinUpFrontDealFactory public upFrontDealFactory;

    address dealAddressNoDeallocationNoDeposit;
    address dealAddressAllowDeallocationNoDeposit;
    address dealAddressNoDeallocation;
    address dealAddressAllowDeallocation;
    address dealAddressAllowList;
    address dealAddressNftGating721;
    address dealAddressNftGating1155;
    address dealAddressLowDecimals;
    address dealAddressNftGating721IdRanges;
    address dealAddressMultipleVestingSchedules;

    function setUp() public {
        AelinAllowList.InitData memory allowListEmpty;
        AelinAllowList.InitData memory allowList = getAllowList();
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);

        vm.startPrank(dealCreatorAddress);

        // Deal initialization
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfigAllowDeallocation = getDealConfigAllowDeallocation();
        IAelinUpFrontDeal.UpFrontDealConfig
            memory dealConfigMultipleVestingSchedules = getDealConfigMultipleVestingSchedules();

        IAelinUpFrontDeal.UpFrontDealData memory dealDataLowDecimals = getDealData();
        dealDataLowDecimals.underlyingDealToken = address(underlyingDealTokenLowDecimals);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721IdRanges = getERC721Collection();

        nftCollectionRules721IdRanges[0].idRanges = getERC721IdRanges();
        nftCollectionRules721IdRanges[1].idRanges = getERC721IdRanges();

        dealAddressNoDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowDeallocationNoDeposit = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressNoDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowDeallocation = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigAllowDeallocation,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressAllowList = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowList
        );

        dealAddressNftGating721 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721,
            allowListEmpty
        );

        dealAddressNftGating1155 = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules1155,
            allowListEmpty
        );

        dealAddressLowDecimals = upFrontDealFactory.createUpFrontDeal(
            dealDataLowDecimals,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        dealAddressNftGating721IdRanges = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRules721IdRanges,
            allowListEmpty
        );

        dealAddressMultipleVestingSchedules = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfigMultipleVestingSchedules,
            nftCollectionRulesEmpty,
            allowListEmpty
        );

        vm.stopPrank();
        vm.startPrank(dealHolderAddress);

        // Deposit underlying tokens to save time for next tests
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressNoDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressNoDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowDeallocation), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowDeallocation).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
        underlyingDealToken.approve(address(dealAddressAllowList), type(uint256).max);
        AelinUpFrontDeal(dealAddressAllowList).depositUnderlyingTokens(1e35);

        deal(address(underlyingDealTokenLowDecimals), dealHolderAddress, type(uint256).max);
        underlyingDealTokenLowDecimals.approve(address(dealAddressLowDecimals), type(uint256).max);
        AelinUpFrontDeal(dealAddressLowDecimals).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating1155), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating1155).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressNftGating721IdRanges), type(uint256).max);
        AelinUpFrontDeal(dealAddressNftGating721IdRanges).depositUnderlyingTokens(1e35);

        underlyingDealToken.approve(address(dealAddressMultipleVestingSchedules), type(uint256).max);
        AelinUpFrontDeal(dealAddressMultipleVestingSchedules).depositUnderlyingTokens(1e35);

        vm.stopPrank();
    }

    function test_SetUp() public {
        assertEq(upFrontDealFactory.UP_FRONT_DEAL_LOGIC(), address(testUpFrontDeal));
        assertEq(upFrontDealFactory.AELIN_ESCROW_LOGIC(), address(testEscrow));
        assertEq(upFrontDealFactory.AELIN_TREASURY(), address(aelinTreasury));
    }

    /*//////////////////////////////////////////////////////////////
                    initialize() / createUpFrontDeal()
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertWhen_CalledTwice() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        vm.expectRevert("can only init once");
        AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).initialize(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListEmpty,
            aelinTreasury,
            address(testEscrow)
        );

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_SameOrNullToken() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.underlyingDealToken = address(purchaseToken);

        vm.expectRevert("purchase & underlying the same");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealData.purchaseToken = address(0);
        vm.expectRevert("cant pass null purchase address");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealData.purchaseToken = address(purchaseToken);
        dealData.underlyingDealToken = address(0);
        vm.expectRevert("cant pass null underlying addr");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_HolderIsNull() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.holder = address(0);

        vm.expectRevert("cant pass null holder address");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_WrongSponsorFee(uint256 _sponsorFee) public {
        vm.startPrank(dealCreatorAddress);
        vm.assume(_sponsorFee > MAX_SPONSOR_FEE);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealData.sponsorFee = _sponsorFee;

        vm.expectRevert("exceeds max sponsor fee");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_WrongVestingDurations(
        uint256 _purchaseDuration,
        uint256 _vestingCliffPeriod,
        uint256 _vestingPeriod
    ) public {
        vm.startPrank(dealCreatorAddress);
        vm.assume(_purchaseDuration > 30 days);
        vm.assume(_vestingCliffPeriod > 1825 days);
        vm.assume(_vestingPeriod > 1825 days);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealConfig.purchaseDuration = _purchaseDuration;

        vm.expectRevert("not within limit");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.purchaseDuration = 1 minutes;
        vm.expectRevert("not within limit");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.purchaseDuration = 10 days;
        dealConfig.vestingSchedules[0].vestingCliffPeriod = _vestingCliffPeriod;
        dealConfig.vestingSchedules[0].vestingPeriod = _vestingPeriod;
        vm.expectRevert("max 5 year cliff");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.vestingSchedules[0].vestingCliffPeriod = 365 days;
        vm.expectRevert("max 5 year vesting");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_WrongVestingDurationsAcrossVestingSchedules(
        uint256 _vestingCliffPeriod,
        uint256 _vestingPeriod
    ) public {
        vm.startPrank(dealCreatorAddress);
        vm.assume(_vestingCliffPeriod > 1825 days);
        vm.assume(_vestingPeriod > 1825 days);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        IAelinUpFrontDeal.VestingSchedule[] memory vestingSchedules = new IAelinUpFrontDeal.VestingSchedule[](2);

        //These vesting periods are fine
        vestingSchedules[0].purchaseTokenPerDealToken = 3e18;
        vestingSchedules[0].vestingCliffPeriod = 60 days;
        vestingSchedules[0].vestingPeriod = 365 days;

        //These aren't
        vestingSchedules[1].purchaseTokenPerDealToken = 3e18;
        vestingSchedules[1].vestingCliffPeriod = _vestingCliffPeriod;
        vestingSchedules[1].vestingPeriod = _vestingPeriod;

        dealConfig.vestingSchedules = vestingSchedules;

        vm.expectRevert("max 5 year cliff");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.vestingSchedules[1].vestingCliffPeriod = 365 days;
        vm.expectRevert("max 5 year vesting");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_IncorrectVestingSchedulesLength() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        //First no vesting schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSchedules;
        dealConfig.vestingSchedules = vestingSchedules;

        vm.expectRevert("no vesting schedules");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        //Then too many
        vestingSchedules = new IAelinUpFrontDeal.VestingSchedule[](11);
        dealConfig.vestingSchedules = vestingSchedules;

        vm.expectRevert("too many vesting schedules");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_WrongDealSetup() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        dealConfig.underlyingDealTokenTotal = 0;
        vm.expectRevert("must have nonzero deal tokens");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.underlyingDealTokenTotal = 100;
        dealConfig.vestingSchedules[0].purchaseTokenPerDealToken = 0;
        vm.expectRevert("invalid deal price");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.vestingSchedules[0].purchaseTokenPerDealToken = 1;
        dealConfig.underlyingDealTokenTotal = 1e28;
        vm.expectRevert("raise min > deal total");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_WrongDealSetupAcrossMultipleVestingSchedules() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        IAelinUpFrontDeal.UpFrontDealData memory dealData = getDealData();
        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig = getDealConfig();

        IAelinUpFrontDeal.VestingSchedule[] memory vestingSchedules = new IAelinUpFrontDeal.VestingSchedule[](3);

        vestingSchedules[0].purchaseTokenPerDealToken = 3e18;
        vestingSchedules[0].vestingCliffPeriod = 60 days;
        vestingSchedules[0].vestingPeriod = 365 days;

        vestingSchedules[1].purchaseTokenPerDealToken = 3e18;
        vestingSchedules[1].vestingCliffPeriod = 60 days;
        vestingSchedules[1].vestingPeriod = 365 days;

        //Invalid price
        vestingSchedules[2].purchaseTokenPerDealToken = 0;
        vestingSchedules[2].vestingCliffPeriod = 60 days;
        vestingSchedules[2].vestingPeriod = 365 days;

        dealConfig.vestingSchedules = vestingSchedules;

        dealConfig.underlyingDealTokenTotal = 100;
        vm.expectRevert("invalid deal price");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        dealConfig.vestingSchedules[2].purchaseTokenPerDealToken = 1;
        dealConfig.underlyingDealTokenTotal = 1e28;
        vm.expectRevert("raise min > deal total");
        upFrontDealFactory.createUpFrontDeal(dealData, dealConfig, nftCollectionRulesEmpty, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_UseAllowListAndNFT() public {
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("cant have allow list & nft");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), getERC721Collection(), getAllowList());
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_Use721And1155() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](4);

        nftCollectionRules[0] = nftCollectionRules721[0];
        nftCollectionRules[1] = nftCollectionRules721[1];
        nftCollectionRules[2] = nftCollectionRules1155[0];
        nftCollectionRules[3] = nftCollectionRules1155[1];

        vm.expectRevert("can only contain 721");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListEmpty);

        nftCollectionRules[0] = nftCollectionRules1155[0];
        nftCollectionRules[1] = nftCollectionRules1155[1];
        nftCollectionRules[2] = nftCollectionRules721[0];
        nftCollectionRules[3] = nftCollectionRules721[1];

        vm.expectRevert("can only contain 1155");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_1155CollectionRulesPurchaseAmtNotZero() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = getERC1155Collection();

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRules[0] = nftCollectionRules1155[0];
        nftCollectionRules[0].purchaseAmount = 1; //Not zero

        vm.expectRevert("purchase amt must be 0 for 1155");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_UseIncompatibleERCType() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        MockERC20 token = new MockERC20("MockToken", "MT", 18);
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRules[0].collectionAddress = address(token);
        nftCollectionRules[0].purchaseAmount = 1e20;

        vm.expectRevert("collection is not compatible");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules, allowListEmpty);

        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_MerkleNoIpfsHash() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInitEmpty;
        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: ""
        });
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("merkle needs ipfs hash");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, getDealConfig(), nftCollectionRulesEmpty, allowListInitEmpty);
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_MerkleAndNftGated() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInitEmpty;

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRules721[0].collectionAddress = address(collection721_1);
        nftCollectionRules721[0].purchaseAmount = 1e20;

        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("cant have nft & merkle");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, getDealConfig(), nftCollectionRules721, allowListInitEmpty);
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_MerkleAndAllowList() public {
        IAelinUpFrontDeal.UpFrontDealData memory merkleDealData;
        AelinAllowList.InitData memory allowListInit;

        merkleDealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
            merkleRoot: 0x5842148bc6ebeb52af882a317c765fccd3ae80589b21a9b8cbf21abb630e46a7,
            ipfsHash: "bafybeifs6trokoqmvhy6k367zbbow7xw62hf3lqsn2zjtjwxllwtcgk5ze"
        });
        address[] memory testAllowListAddresses = new address[](1);
        uint256[] memory testAllowListAmounts = new uint256[](1);
        testAllowListAddresses[0] = user1;
        testAllowListAmounts[0] = 1e18;
        allowListInit.allowListAddresses = testAllowListAddresses;
        allowListInit.allowListAmounts = testAllowListAmounts;
        vm.startPrank(dealCreatorAddress);
        vm.expectRevert("cant have allow list & merkle");
        upFrontDealFactory.createUpFrontDeal(merkleDealData, getDealConfig(), nftCollectionRulesEmpty, allowListInit);
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_MaxIdRangesExceeded() public {
        vm.startPrank(dealCreatorAddress);

        AelinAllowList.InitData memory allowListEmpty;
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = getERC721Collection();

        AelinNftGating.IdRange[] memory idRanges = new AelinNftGating.IdRange[](11);

        for (uint256 i; i < 11; i++) {
            idRanges[i].begin = 0;
            idRanges[i].end = 1;
        }

        nftCollectionRules721[0].idRanges = idRanges;

        vm.expectRevert("too many ranges");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules721, allowListEmpty);
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_RevertWhen_IdRangesAreIncorrect() public {
        AelinAllowList.InitData memory allowListEmpty;

        //First element of CollectionRules, first element of idRanges
        vm.startPrank(dealCreatorAddress);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721A = getERC721Collection();

        nftCollectionRules721A[0].idRanges = getERC721IdRanges();
        nftCollectionRules721A[0].idRanges[0].begin = 1;
        nftCollectionRules721A[0].idRanges[0].end = 0;

        vm.expectRevert("begin greater than end");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules721A, allowListEmpty);
        vm.stopPrank();

        //First element of CollectionRules, second element of idRanges
        vm.startPrank(dealCreatorAddress);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721B = getERC721Collection();

        nftCollectionRules721B[0].idRanges = getERC721IdRanges();
        nftCollectionRules721B[0].idRanges[1].begin = 1;
        nftCollectionRules721B[0].idRanges[1].end = 0;

        vm.expectRevert("begin greater than end");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules721B, allowListEmpty);
        vm.stopPrank();

        //Second element of CollectionRules, first element of idRanges
        vm.startPrank(dealCreatorAddress);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721C = getERC721Collection();

        nftCollectionRules721C[1].idRanges = getERC721IdRanges();
        nftCollectionRules721C[1].idRanges[0].begin = 1;
        nftCollectionRules721C[1].idRanges[0].end = 0;

        vm.expectRevert("begin greater than end");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules721C, allowListEmpty);
        vm.stopPrank();

        //Second element of CollectionRules, second element of idRanges
        vm.startPrank(dealCreatorAddress);

        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721D = getERC721Collection();

        nftCollectionRules721D[1].idRanges = getERC721IdRanges();
        nftCollectionRules721D[1].idRanges[1].begin = 1;
        nftCollectionRules721D[1].idRanges[1].end = 0;

        vm.expectRevert("begin greater than end");
        upFrontDealFactory.createUpFrontDeal(getDealData(), getDealConfig(), nftCollectionRules721D, allowListEmpty);
        vm.stopPrank();
    }

    function test_CreateUpFrontDeal_NoDeallocationNoDeposit() public {
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
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingCliffExpiries(0), 0);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).vestingExpiries(0), 0);
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
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e28);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).dealConfig();
        assertFalse(tempBool);
        // vesting schedule
        (tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 3e18);
        (, tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 60 days);
        (, , tempUint) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 365 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
    }

    function test_CreateUpFrontDeal_AllowDeallocationNoDeposit() public {
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
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).vestingCliffExpiries(0), 0);
        assertEq(AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).vestingExpiries(0), 0);
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
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 0);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).dealConfig();
        assertTrue(tempBool);
        // vesting schedule
        (tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 3e18);
        (, tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 60 days);
        (, , tempUint) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getVestingScheduleDetails(0);
        assertEq(tempUint, 365 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocationNoDeposit).getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
    }

    function test_CreateUpFrontDeal_NoDeallocation() public {
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
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiries(0),
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
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 1e28);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).dealConfig();
        assertFalse(tempBool);
        // vesting schedule
        (tempUint, , ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 3e18);
        (, tempUint, ) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 60 days);
        (, , tempUint) = AelinUpFrontDeal(dealAddressNoDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 365 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = AelinUpFrontDeal(dealAddressNoDeallocation).getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
    }

    function test_CreateUpFrontDeal_NoDeallocationLowDecimals() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressLowDecimals);
        // balance
        assertEq(underlyingDealTokenLowDecimals.balanceOf(address(dealAddressLowDecimals)), 1e35);
        // deal contract storage
        assertEq(deal.dealFactory(), address(upFrontDealFactory));
        assertEq(deal.name(), "aeUpFrontDeal-DEAL");
        assertEq(deal.symbol(), "aeUD-DEAL");
        assertEq(deal.dealStart(), block.timestamp);
        assertEq(deal.aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(deal.aelinTreasuryAddress(), aelinTreasury);
        assertEq(deal.tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(deal.purchaseExpiry(), block.timestamp + 10 days);
        assertEq(deal.vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
        assertEq(deal.vestingExpiries(0), block.timestamp + 10 days + 60 days + 365 days);
        // deal data
        (tempString, , , , , , , , ) = deal.dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = deal.dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = deal.dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = deal.dealData();
        assertEq(tempAddress, address(underlyingDealTokenLowDecimals));
        (, , , , tempAddress, , , , ) = deal.dealData();
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = deal.dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = deal.dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = deal.dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = deal.dealConfig();
        assertEq(tempUint, 1e28);
        (, , tempUint, ) = deal.dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = deal.dealConfig();
        assertFalse(tempBool);
        // vesting schedule
        (tempUint, , ) = deal.getVestingScheduleDetails(0);
        assertEq(tempUint, 3e18);
        (, tempUint, ) = deal.getVestingScheduleDetails(0);
        assertEq(tempUint, 60 days);
        (, , tempUint) = deal.getVestingScheduleDetails(0);
        assertEq(tempUint, 365 days);
        // test allow list
        (, , , tempBool) = deal.getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = deal.getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
        assertEq(underlyingDealTokenLowDecimals.decimals(), 2);
    }

    function test_CreateUpFrontDeal_AllowDeallocation() public {
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
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocation).vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNoDeallocation).vestingExpiries(0),
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
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 0);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).dealConfig();
        assertTrue(tempBool);
        // vesting schedule
        (tempUint, , ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 3e18);
        (, tempUint, ) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 60 days);
        (, , tempUint) = AelinUpFrontDeal(dealAddressAllowDeallocation).getVestingScheduleDetails(0);
        assertEq(tempUint, 365 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = AelinUpFrontDeal(dealAddressAllowDeallocation).getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
    }

    function test_CreateUpFrontDeal_AllowList() public {
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
        assertEq(AelinUpFrontDeal(dealAddressAllowList).vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
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
        (, tempBool) = AelinUpFrontDeal(dealAddressAllowList).getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
    }

    function test_CreateUpFrontDeal_MultipleVestingSchedules() public {
        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        AelinUpFrontDeal deal = AelinUpFrontDeal(dealAddressMultipleVestingSchedules);
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressMultipleVestingSchedules)), 1e35);
        // deal contract storage
        assertEq(deal.dealFactory(), address(upFrontDealFactory));
        assertEq(deal.name(), "aeUpFrontDeal-DEAL");
        assertEq(deal.symbol(), "aeUD-DEAL");
        assertEq(deal.dealStart(), block.timestamp);
        assertEq(deal.aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(deal.aelinTreasuryAddress(), aelinTreasury);
        assertEq(deal.tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(deal.purchaseExpiry(), block.timestamp + 10 days);
        // deal data
        (tempString, , , , , , , , ) = deal.dealData();
        assertEq(tempString, "DEAL");
        (, tempString, , , , , , , ) = deal.dealData();
        assertEq(tempString, "DEAL");
        (, , tempAddress, , , , , , ) = deal.dealData();
        assertEq(tempAddress, address(purchaseToken));
        (, , , tempAddress, , , , , ) = deal.dealData();
        assertEq(tempAddress, address(underlyingDealToken));
        (, , , , tempAddress, , , , ) = deal.dealData();
        assertEq(tempAddress, dealHolderAddress);
        (, , , , , tempAddress, , , ) = deal.dealData();
        assertEq(tempAddress, dealCreatorAddress);
        (, , , , , , tempUint, , ) = deal.dealData();
        assertEq(tempUint, 1e18);
        // deal config
        (tempUint, , , ) = deal.dealConfig();
        assertEq(tempUint, 1e35);
        (, tempUint, , ) = deal.dealConfig();
        assertEq(tempUint, 1e28);
        (, , tempUint, ) = deal.dealConfig();
        assertEq(tempUint, 10 days);
        (, , , tempBool) = deal.dealConfig();
        assertFalse(tempBool);

        // vesting schedules
        for (uint256 i; i < 10; i++) {
            (tempUint, , ) = deal.getVestingScheduleDetails(i);
            assertEq(tempUint, 3e18 + (1e18 * i));
            (, tempUint, ) = deal.getVestingScheduleDetails(i);
            assertEq(tempUint, 60 days + (10 days * i));
            (, , tempUint) = deal.getVestingScheduleDetails(i);
            assertEq(tempUint, 365 days + (10 days * i));
            assertEq(deal.vestingCliffExpiries(i), block.timestamp + 10 days + 60 days + (10 days * i));
            assertEq(deal.vestingExpiries(i), block.timestamp + 10 days + 60 days + 365 days + (20 days * i));
        }

        // test allow list
        (, , , tempBool) = deal.getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        (, tempBool) = deal.getNftGatingDetails(address(0), 0);
        assertFalse(tempBool);
        assertEq(underlyingDealTokenLowDecimals.decimals(), 2);
    }

    function test_CreateUpFrontDeal_NftGating721() public {
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating721).vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGating721).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, tempBool) = AelinUpFrontDeal(dealAddressNftGating721).getNftGatingDetails(address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, , tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collection721_1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collection721_1));
        (tempUint, tempAddress, , tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721)
            .getNftCollectionDetails(address(collection721_2));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collection721_2));
    }

    function test_CreateUpFrontDeal_NftGating721IdRanges() public {
        address tempAddress;
        uint256 tempUint;
        bool tempBool;
        // balance
        assertEq(underlyingDealToken.balanceOf(address(dealAddressNftGating721IdRanges)), 1e35);
        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).tokenCount(), 0);
        // underlying has deposited so deal has started
        assertEq(AelinUpFrontDeal(dealAddressNftGating721IdRanges).purchaseExpiry(), block.timestamp + 10 days);
        assertEq(
            AelinUpFrontDeal(dealAddressNftGating721IdRanges).vestingCliffExpiries(0),
            block.timestamp + 10 days + 60 days
        );
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        AelinNftGating.IdRange[] memory idRanges;
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, tempBool) = AelinUpFrontDeal(dealAddressNftGating721IdRanges).getNftGatingDetails(address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, idRanges, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721IdRanges)
            .getNftCollectionDetails(address(collection721_1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collection721_1));
        assertEq(idRanges[0].begin, 1);
        assertEq(idRanges[0].end, 2);
        assertEq(idRanges[1].begin, 1e20);
        assertEq(idRanges[1].end, 1e21);

        (tempUint, tempAddress, idRanges, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating721IdRanges)
            .getNftCollectionDetails(address(collection721_2));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collection721_2));
        assertEq(idRanges[0].begin, 1);
        assertEq(idRanges[0].end, 2);
        assertEq(idRanges[1].begin, 1e20);
        assertEq(idRanges[1].end, 1e21);
    }

    function test_CreateUpFrontDeal_NftGating1155() public {
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
        assertEq(AelinUpFrontDeal(dealAddressNftGating1155).vestingCliffExpiries(0), block.timestamp + 10 days + 60 days);
        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddressNftGating1155).getAllowList(address(0));
        assertFalse(tempBool);
        // test nft gating
        AelinNftGating.IdRange[] memory idRanges;
        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        (, tempBool) = AelinUpFrontDeal(dealAddressNftGating1155).getNftGatingDetails(address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, idRanges, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collection1155_1));
        assertEq(tempUint, 0);
        assertEq(tempAddress, address(collection1155_1));
        assertEq(tempUintArray1[0], 1);
        assertEq(tempUintArray1[1], 2);
        assertEq(tempUintArray2[0], 10);
        assertEq(tempUintArray2[1], 20);
        (tempUint, tempAddress, idRanges, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddressNftGating1155)
            .getNftCollectionDetails(address(collection1155_2));
        assertEq(tempUint, 0);
        assertEq(tempAddress, address(collection1155_2));
        assertEq(tempUintArray1[0], 10);
        assertEq(tempUintArray1[1], 20);
        assertEq(tempUintArray2[0], 1000);
        assertEq(tempUintArray2[1], 2000);
    }

    /*//////////////////////////////////////////////////////////////
                    pre depositUnderlyingTokens()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ClaimableUnderlyingTokens_DepositIncomplete(address _testAddress, uint256 _tokenId) public {
        vm.assume(_testAddress != address(0));
        vm.prank(_testAddress);
        assertEq(AelinUpFrontDeal(dealAddressNoDeallocationNoDeposit).claimableUnderlyingTokens(_tokenId, 0), 0);
        vm.stopPrank();
    }
}
