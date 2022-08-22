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
            purchaseTokenPerDealToken: _purchaseTokenPerDealToken,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: _allowDeallocation
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
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
            purchaseTokenPerDealToken: _purchaseTokenPerDealToken,
            purchaseRaiseMinimum: _purchaseRaiseMinimum,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
    }

    function testCreateUpFrontDealReverts() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        vm.expectRevert("cant pass null purchase token address");
        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
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
        dealAddress = upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);

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
        dealAddress = upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
    }

    function testFuzzCreateDealWhenDepositNotEnough(
        address _testAddress,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _depositUnderlyingAmount,
        bool _allowDeallocation
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);
        vm.assume(_depositUnderlyingAmount > 0);
        vm.assume(_depositUnderlyingAmount < _underlyingDealTokenTotal);
        vm.assume(_testAddress != address(0));

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: _allowDeallocation
        });

        // create when the msg.sender does not have enough underlying tokens to fulfill the _depositUnderlyingAmount
        vm.expectRevert("not enough balance");
        upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            _depositUnderlyingAmount
        );
    }

    function testFuzzCreateDealWithNonFullDeposit(
        address _testAddress,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _depositUnderlyingAmount,
        bool _allowDeallocation
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);
        vm.assume(_depositUnderlyingAmount > 0);
        vm.assume(_depositUnderlyingAmount < _underlyingDealTokenTotal);
        vm.assume(_testAddress != address(0));

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: _allowDeallocation
        });

        // create when the msg.sender does not have enough underlying tokens to fulfill the _depositUnderlyingAmount
        vm.expectRevert("not enough balance");
        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            _depositUnderlyingAmount
        );

        bool _tempBool;

        // create when msg.sender has enough underlying tokens to fulfill the _depositUnderlyingAmount
        vm.startPrank(_testAddress);
        deal(address(underlyingDealToken), _testAddress, type(uint256).max);
        underlyingDealToken.approve(address(upFrontDealFactory), type(uint256).max);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), _testAddress, _depositUnderlyingAmount);
        dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            _depositUnderlyingAmount
        );
        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinUpFrontDeal(dealAddress).vestingExpiry(), 0);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
    }

    function testFuzzCreateDealWithFullDeposit(
        address _testAddress,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _depositUnderlyingAmount,
        bool _allowDeallocation
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);
        vm.assume(_depositUnderlyingAmount >= _underlyingDealTokenTotal);
        vm.assume(_testAddress != address(0));

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: _allowDeallocation
        });

        // create when _depositUnderlyingAmount is enough to fulfill the underlying total amount
        vm.startPrank(_testAddress);
        deal(address(underlyingDealToken), _testAddress, type(uint256).max);
        underlyingDealToken.approve(address(upFrontDealFactory), type(uint256).max);
        vm.expectEmit(true, true, false, false);
        emit DepositDealToken(address(underlyingDealToken), _testAddress, _depositUnderlyingAmount);
        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            _depositUnderlyingAmount
        );

        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        assertEq(AelinUpFrontDeal(dealAddress).purchaseExpiry(), block.timestamp + _purchaseDuration);
        assertEq(
            AelinUpFrontDeal(dealAddress).vestingCliffExpiry(),
            block.timestamp + _purchaseDuration + _vestingCliffPeriod
        );
        assertEq(
            AelinUpFrontDeal(dealAddress).vestingExpiry(),
            block.timestamp + _purchaseDuration + _vestingCliffPeriod + _vestingPeriod
        );

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
    }

    function testFuzzCreateDealWithAllowList(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        address[] memory _tempAddressArray;
        uint256[] memory _tempUintArray;
        (_tempAddressArray, _tempUintArray, , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertTrue(_tempBool);
        assertEq(testAllowListAddresses.length, _tempAddressArray.length);
        assertEq(_tempAddressArray[0], address(0x1337));
        assertEq(_tempAddressArray[1], address(0xBEEF));
        assertEq(_tempAddressArray[2], address(0xDEED));
        assertEq(_tempUintArray[0], 1e18);
        assertEq(_tempUintArray[1], 1e18);
        assertEq(_tempUintArray[2], 1e18);
        for (uint256 i; i < _tempAddressArray.length; ) {
            (, , _tempUint, ) = AelinUpFrontDeal(dealAddress).getAllowList(_tempAddressArray[i]);
            assertEq(_tempUint, testAllowListAmounts[i]);
            unchecked {
                ++i;
            }
        }

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
    }

    // fails because testAllowListAddresses[] and testAllowListAmounts[] are not the same size
    function testFuzzCreateDealWithAllowListNotSameSize(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod
    ) public {
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: _purchaseDuration,
            vestingPeriod: _vestingPeriod,
            vestingCliffPeriod: _vestingCliffPeriod,
            allowDeallocation: false
        });

        vm.expectRevert("allowListAddresses and allowListAmounts arrays should have the same length");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
    }

    function testCreateDealWith721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        uint256[] memory _tempUintArray1;
        uint256[] memory _tempUintArray2;
        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(_tempBool);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(_tempUint, 1e20);
        assertEq(_tempAddress, address(collectionAddress1));
        assertTrue(_tempBool);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress2));
        assertEq(_tempUint, 1e22);
        assertEq(_tempAddress, address(collectionAddress2));
        assertFalse(_tempBool);
    }

    function testCreatePoolWithPunksAnd721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        uint256[] memory _tempUintArray1;
        uint256[] memory _tempUintArray2;
        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(_tempBool);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress1));
        assertEq(_tempUint, 1e20);
        assertEq(_tempAddress, address(collectionAddress1));
        assertTrue(_tempBool);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(punks));
        assertEq(_tempUint, 1e22);
        assertEq(_tempAddress, address(punks));
        assertFalse(_tempBool);
    }

    function testCreatePoolWith1155() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        address dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            0
        );

        string memory _tempString;
        address _tempAddress;
        uint256 _tempUint;
        bool _tempBool;

        // deal contract storage
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).decimals(), MockERC20(underlyingDealToken).decimals());
        assertEq(AelinUpFrontDeal(dealAddress).dealStart(), block.timestamp);
        assertEq(AelinUpFrontDeal(dealAddress).aelinEscrowLogicAddress(), address(testEscrow));
        assertEq(AelinUpFrontDeal(dealAddress).aelinTreasuryAddress(), aelinTreasury);

        // deal data
        (_tempString, , , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, _tempString, , , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempString, "DEAL");
        (, , _tempAddress, , , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(purchaseToken));
        (, , , _tempAddress, , , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(underlyingDealToken));
        (, , , , _tempAddress, , ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.holder));
        (, , , , , _tempAddress, ) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempAddress, address(_dealData.sponsor));
        (, , , , , , _tempUint) = AelinUpFrontDeal(dealAddress).dealData();
        assertEq(_tempUint, _dealData.sponsorFee);

        // deal config
        (_tempUint, , , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.underlyingDealTokenTotal);
        (, _tempUint, , , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseTokenPerDealToken);
        (, , _tempUint, , , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseRaiseMinimum);
        (, , , _tempUint, , , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.purchaseDuration);
        (, , , , _tempUint, , ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingPeriod);
        (, , , , , _tempUint, ) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempUint, _dealConfig.vestingCliffPeriod);
        (, , , , , , _tempBool) = AelinUpFrontDeal(dealAddress).dealConfig();
        assertEq(_tempBool, _dealConfig.allowDeallocation);

        // test allow list
        (, , , _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        uint256[] memory _tempUintArray1;
        uint256[] memory _tempUintArray2;
        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertTrue(_tempBool);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress3));
        assertEq(_tempUint, 1e20);
        assertEq(_tempAddress, address(collectionAddress3));
        assertTrue(_tempBool);
        assertEq(_tempUintArray1[0], 1);
        assertEq(_tempUintArray1[1], 2);
        assertEq(_tempUintArray2[0], 100);
        assertEq(_tempUintArray2[1], 200);
        (_tempUint, _tempAddress, _tempBool, _tempUintArray1, _tempUintArray2) = AelinUpFrontDeal(dealAddress)
            .getNftCollectionDetails(address(collectionAddress4));
        assertEq(_tempUint, 1e22);
        assertEq(_tempAddress, address(collectionAddress4));
        assertFalse(_tempBool);
        assertEq(_tempUintArray1[0], 10);
        assertEq(_tempUintArray1[1], 20);
        assertEq(_tempUintArray2[0], 1000);
        assertEq(_tempUintArray2[1], 2000);
    }

    function testRevertCreateDealWith1155and721() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        vm.expectRevert("can only contain 1155");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
    }

    function testRevertCreateDealWith721and1155() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](2);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        vm.expectRevert("can only contain 721");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
    }

    // reverts when some an address other than 721 or 1155 is provided
    function testCreatePoolNonCompatibleAddress(address collection) public {
        vm.assume(collection != address(collectionAddress1));
        vm.assume(collection != address(collectionAddress2));
        vm.assume(collection != address(collectionAddress3));
        vm.assume(collection != address(collectionAddress4));
        vm.assume(collection != punks);

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);
        AelinAllowList.InitData memory _allowListInit;

        _nftCollectionRules[0].collectionAddress = collection;
        _nftCollectionRules[0].purchaseAmount = 1e20;
        _nftCollectionRules[0].purchaseAmountPerToken = true;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        vm.expectRevert("collection is not compatible");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
    }

    function testRevertNftAndAllowList() public {
        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules = new AelinNftGating.NftCollectionRules[](1);
        AelinAllowList.InitData memory _allowListInit;

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
            purchaseTokenPerDealToken: 1e18,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 30 days,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 1 days,
            allowDeallocation: false
        });

        vm.expectRevert("cannot have allow list and nft gating");
        upFrontDealFactory.createUpFrontDeal(_dealData, _dealConfig, _nftCollectionRules, _allowListInit, 0);
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
