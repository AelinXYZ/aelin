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

contract AelinUpFrontDealFactoryTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    uint256 constant BASE = 10000;
    uint256 constant MAX_SPONSOR_FEE = 1500;
    uint256 constant AELIN_FEE = 200;

    uint256 constant MAX_VESTING_SCHEDULES = 10;

    AelinUpFrontDeal public testUpFrontDeal;
    AelinUpFrontDealFactory public upFrontDealFactory;
    AelinFeeEscrow public testEscrow;
    MockERC20 public purchaseToken;
    MockERC20 public underlyingDealToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;
    MockERC1155 public collectionAddress3;
    MockERC1155 public collectionAddress4;

    IAelinUpFrontDeal.UpFrontDealData public dealData;
    IAelinUpFrontDeal.UpFrontDealConfig public dealConfig;

    function setUp() public {
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);
        purchaseToken = new MockERC20("MockPool", "MP");
        underlyingDealToken = new MockERC20("MockDeal", "MD");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC1155("");
        collectionAddress4 = new MockERC1155("");

        assertEq(upFrontDealFactory.UP_FRONT_DEAL_LOGIC(), address(testUpFrontDeal));
        assertEq(upFrontDealFactory.AELIN_ESCROW_LOGIC(), address(testEscrow));
        assertEq(upFrontDealFactory.AELIN_TREASURY(), address(aelinTreasury));
    }

    /*//////////////////////////////////////////////////////////////
                            createDeal
    //////////////////////////////////////////////////////////////*/

    // without depositing underlying upon creation
    // without minimum raise
    // without any NFT Collection Rules
    // without any Allow List
    function testFuzzCreateDeal(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        vm.assume(_sponsorFee < MAX_SPONSOR_FEE);
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseTokenPerDealToken > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = _purchaseTokenPerDealToken;
        vestingSingle[0].vestingCliffPeriod = _vestingCliffPeriod;
        vestingSingle[0].vestingPeriod = _vestingPeriod;

        unchecked {
            uint256 test = _purchaseTokenPerDealToken * _underlyingDealTokenTotal;
            vm.assume(test / _purchaseTokenPerDealToken == _underlyingDealTokenTotal);
            test = test / 10**MockERC20(underlyingDealToken).decimals();
            vm.assume(test > 0);
        }

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: _sponsorFee
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: _underlyingDealTokenTotal,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingSchedule: vestingSingle,
            allowDeallocation: _allowDeallocation
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testFuzzCreateDealWithMinimumRaise(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseTokenPerDealToken > 0);
        vm.assume(_purchaseRaiseMinimum > 0);

        if (_purchaseRaiseMinimum > 0) {
            uint8 underlyingTokenDecimals = MockERC20(underlyingDealToken).decimals();
            (, uint256 numerator) = SafeMath.tryMul(_purchaseTokenPerDealToken, _underlyingDealTokenTotal);
            uint256 totalIntendedRaise = numerator / 10**underlyingTokenDecimals;
            vm.assume(totalIntendedRaise != 0);
            vm.assume(_purchaseRaiseMinimum <= totalIntendedRaise);
        }

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = _purchaseTokenPerDealToken;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: _underlyingDealTokenTotal,
            purchaseRaiseMinimum: _purchaseRaiseMinimum,
            purchaseDuration: 10 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    function testCreateUpFrontDealReverts() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        // Revert for passing in null purchase token address

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(0),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("cant pass null purchase token address");
        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        // Revert for passing in null underlying deal token address

        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(0),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        vm.expectRevert("cant pass null underlying token address");
        dealAddress = upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);

        // Revert for passing in null holder address

        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        vm.expectRevert("cant pass null holder address");
        dealAddress = upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testFuzzCreateDealWithAllowList(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_underlyingDealTokenTotal < 1e41);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = _vestingCliffPeriod;
        vestingSingle[0].vestingPeriod = _vestingPeriod;

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 1e18;
        testAllowListAmounts[2] = 1e18;

        _allowListInit.allowListAddresses = testAllowListAddresses;
        _allowListInit.allowListAmounts = testAllowListAmounts;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: _underlyingDealTokenTotal,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        address[] memory tempAddressArray;
        uint256[] memory tempUintArray;
        (tempAddressArray, tempUintArray, , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertTrue(tempBool);
        assertEq(testAllowListAddresses.length, tempAddressArray.length);
        assertEq(tempAddressArray[0], address(0x1337));
        assertEq(tempAddressArray[1], address(0xBEEF));
        assertEq(tempAddressArray[2], address(0xDEED));
        assertEq(tempUintArray[0], 1e18);
        assertEq(tempUintArray[1], 1e18);
        assertEq(tempUintArray[2], 1e18);
        for (uint256 i; i < tempAddressArray.length; ) {
            (, , tempUint, ) = AelinUpFrontDeal(dealAddress).getAllowList(tempAddressArray[i]);
            assertEq(tempUint, testAllowListAmounts[i]);
            unchecked {
                ++i;
            }
        }

        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    // fails because testAllowListAddresses[] and testAllowListAmounts[] are not the same size
    function testFuzzCreateDealWithAllowListNotSameSize(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_underlyingDealTokenTotal < 1e41);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = _vestingCliffPeriod;
        vestingSingle[0].vestingPeriod = _vestingPeriod;

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](2);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 1e18;

        _allowListInit.allowListAddresses = testAllowListAddresses;
        _allowListInit.allowListAmounts = testAllowListAmounts;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: _underlyingDealTokenTotal,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("allowListAddresses and allowListAmounts arrays should have the same length");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testCreateDealWith721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

        _nftCollectionRules[1].collectionAddress = address(collectionAddress2);
        _nftCollectionRules[1].purchaseAmount = 1e22;
        _nftCollectionRules[1].purchaseAmountPerToken = false;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress1));
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress2));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collectionAddress2));
        assertFalse(tempBool);
    }

    function testCreatePoolWithPunksAnd721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

        _nftCollectionRules[1].collectionAddress = address(punks);
        _nftCollectionRules[1].purchaseAmount = 1e22;
        _nftCollectionRules[1].purchaseAmountPerToken = false;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress1));
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(punks));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(punks));
        assertFalse(tempBool);
    }

    function testCreatePoolWith1155() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress3);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;
        _nftCollectionRules[0].tokenIds = new uint256[](2);
        _nftCollectionRules[0].minTokensEligible = new uint256[](2);
        _nftCollectionRules[0].tokenIds[0] = 1;
        _nftCollectionRules[0].tokenIds[1] = 2;
        _nftCollectionRules[0].minTokensEligible[0] = 100;
        _nftCollectionRules[0].minTokensEligible[1] = 200;

        _nftCollectionRules[1].collectionAddress = address(collectionAddress4);
        _nftCollectionRules[1].purchaseAmount = 1e22;
        _nftCollectionRules[1].purchaseAmountPerToken = false;
        _nftCollectionRules[1].tokenIds = new uint256[](2);
        _nftCollectionRules[1].minTokensEligible = new uint256[](2);
        _nftCollectionRules[1].tokenIds[0] = 10;
        _nftCollectionRules[1].tokenIds[1] = 20;
        _nftCollectionRules[1].minTokensEligible[0] = 1000;
        _nftCollectionRules[1].minTokensEligible[1] = 2000;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingSingle[0].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        uint256[] memory tempUintArray1;
        uint256[] memory tempUintArray2;
        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(tempBool);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress3));
        assertEq(tempUint, 1e20);
        assertEq(tempAddress, address(collectionAddress3));
        assertTrue(tempBool);
        assertEq(tempUintArray1[0], 1);
        assertEq(tempUintArray1[1], 2);
        assertEq(tempUintArray2[0], 100);
        assertEq(tempUintArray2[1], 200);
        (tempUint, tempAddress, tempBool, tempUintArray1, tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress4));
        assertEq(tempUint, 1e22);
        assertEq(tempAddress, address(collectionAddress4));
        assertFalse(tempBool);
        assertEq(tempUintArray1[0], 10);
        assertEq(tempUintArray1[1], 20);
        assertEq(tempUintArray2[0], 1000);
        assertEq(tempUintArray2[1], 2000);
    }

    function testRevertCreateDealWith1155and721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress3);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;
        _nftCollectionRules[0].tokenIds = new uint256[](2);
        _nftCollectionRules[0].minTokensEligible = new uint256[](2);
        _nftCollectionRules[0].tokenIds[0] = 1;
        _nftCollectionRules[0].tokenIds[1] = 2;
        _nftCollectionRules[0].minTokensEligible[0] = 100;
        _nftCollectionRules[0].minTokensEligible[1] = 200;

        _nftCollectionRules[1].collectionAddress = address(collectionAddress1);
        _nftCollectionRules[1].purchaseAmount = 1e20;
        _nftCollectionRules[1].purchaseAmountPerToken = true;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("can only contain 1155");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testRevertCreateDealWith721and1155() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

        _nftCollectionRules[1].collectionAddress = address(collectionAddress3);
        _nftCollectionRules[1].purchaseAmount = 1e20;
        _nftCollectionRules[1].purchaseAmountPerToken = true;
        _nftCollectionRules[1].tokenIds = new uint256[](2);
        _nftCollectionRules[1].minTokensEligible = new uint256[](2);
        _nftCollectionRules[1].tokenIds[0] = 1;
        _nftCollectionRules[1].tokenIds[1] = 2;
        _nftCollectionRules[1].minTokensEligible[0] = 100;
        _nftCollectionRules[1].minTokensEligible[1] = 200;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("can only contain 721");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    // reverts when some an address other than 721 or 1155 is provided
    function testCreatePoolNonCompatibleAddress() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);
        AelinAllowList.InitData memory _allowListInit;

        _nftCollectionRules[0].collectionAddress = address(testEscrow);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("collection is not compatible");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testRevertNftAndAllowList() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingSingle = new IAelinUpFrontDeal.VestingSchedule[](1);
        vestingSingle[0].purchaseTokenPerDealToken = 1e18;
        vestingSingle[0].vestingCliffPeriod = 1 days;
        vestingSingle[0].vestingPeriod = 10 days;

        _nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = address(0x1337);
        testAllowListAddresses[1] = address(0xBEEF);
        testAllowListAddresses[2] = address(0xDEED);
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 1e18;
        testAllowListAmounts[2] = 1e18;

        _allowListInit.allowListAddresses = testAllowListAddresses;
        _allowListInit.allowListAmounts = testAllowListAmounts;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingSingle,
            allowDeallocation: false
        });

        vm.expectRevert("cannot have allow list and nft gating");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    // MULTIPLE VESTING SCHEDULES

    function testCreateDealNoSchedule() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        IAelinUpFrontDeal.VestingSchedule[] memory vestingMulti;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingMulti,
            allowDeallocation: false
        });

        vm.expectRevert("must have vesting schedule");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testCreateDealTooManySchedules() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingMulti = new IAelinUpFrontDeal.VestingSchedule[](
            MAX_VESTING_SCHEDULES + 1
        );
        vestingMulti[0].purchaseTokenPerDealToken = 1e18;
        vestingMulti[0].vestingCliffPeriod = 1 days;
        vestingMulti[0].vestingPeriod = 10 days;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 200
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 2e27,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingSchedule: vestingMulti,
            allowDeallocation: false
        });

        vm.expectRevert("exceeds max amount of vesting schedules");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit);
    }

    function testCreateDealMultipleSchedules(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken1,
        uint256 _purchaseTokenPerDealToken2,
        uint256 _vestingPeriod1,
        uint256 _vestingCliffPeriod1,
        uint256 _vestingPeriod2,
        uint256 _vestingCliffPeriod2
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_underlyingDealTokenTotal < 1e41);
        vm.assume(_purchaseTokenPerDealToken1 > 0);
        vm.assume(_purchaseTokenPerDealToken2 > 0);
        vm.assume(_vestingCliffPeriod1 <= 1825 days);
        vm.assume(_vestingPeriod1 <= 1825 days);
        vm.assume(_vestingCliffPeriod2 <= 1825 days);
        vm.assume(_vestingPeriod2 <= 1825 days);

        // Vesting Schedules
        IAelinUpFrontDeal.VestingSchedule[] memory vestingMulti = new IAelinUpFrontDeal.VestingSchedule[](2);
        vestingMulti[0].purchaseTokenPerDealToken = _purchaseTokenPerDealToken1;
        vestingMulti[0].vestingCliffPeriod = _vestingCliffPeriod1;
        vestingMulti[0].vestingPeriod = _vestingPeriod1;
        vestingMulti[1].purchaseTokenPerDealToken = _purchaseTokenPerDealToken2;
        vestingMulti[1].vestingCliffPeriod = _vestingCliffPeriod2;
        vestingMulti[1].vestingPeriod = _vestingPeriod2;

        unchecked {
            uint256 highestPrice = _purchaseTokenPerDealToken1 > _purchaseTokenPerDealToken2
                ? _purchaseTokenPerDealToken1
                : _purchaseTokenPerDealToken2;
            uint256 test = highestPrice * _underlyingDealTokenTotal;
            vm.assume(test / highestPrice == _underlyingDealTokenTotal);
            test = test / 10**MockERC20(underlyingDealToken).decimals();
            vm.assume(test > 0);
        }

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        IAelinUpFrontDeal.UpFrontDealData memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0x123),
            sponsorFee: 0
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory _dealConfig;
        _dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: _underlyingDealTokenTotal,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 10 days,
            vestingSchedule: vestingMulti,
            allowDeallocation: true
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit
        );

        string memory tempString;
        address tempAddress;
        uint256 tempUint;
        bool tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(0), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(0), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(1), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(1), 0);

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
        assertEq(tempAddress, address(_dealData.holder));
        (, , , , , tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempAddress, address(_dealData.sponsor));
        (, , , , , , tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(tempUint, _dealData.sponsorFee);

        // deal config
        (tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.underlyingDealTokenTotal);
        (, tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempUint, _dealConfig.purchaseDuration);
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(tempBool, _dealConfig.allowDeallocation);
        // vesting schedule details
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingMulti[0].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingMulti[0].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(0);
        assertEq(tempUint, vestingMulti[0].vestingPeriod);
        (tempUint, , ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(1);
        assertEq(tempUint, vestingMulti[1].purchaseTokenPerDealToken);
        (, tempUint, ) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(1);
        assertEq(tempUint, vestingMulti[1].vestingCliffPeriod);
        (, , tempUint) = AelinUpFrontDeal(dealAddress).getVestingScheduleDetails(1);
        assertEq(tempUint, vestingMulti[1].vestingPeriod);

        // test allow list
        (, , , tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(tempBool);

        // test nft gating
        (, , tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(tempBool);
    }

    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );

    event CreateUpFrontDeal(
        address indexed dealAddress,
        string name,
        string symbol,
        address purchaseToken,
        address underlyingDealToken,
        address indexed holder,
        address indexed sponsor,
        uint256 sponsorFee
    );
}
