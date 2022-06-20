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

    address[] public allowListAddresses;
    uint256[] public allowListAmounts;

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
    // without any NFT Collection Rules
    // without any Allow List
    function testFuzzCreateDeal(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        vm.assume(_sponsorFee < 15e18);
        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseTokenPerDealToken > 0);
        /*
        bool _success;
        if (_purchaseRaiseMinimum > 0) {
            uint8 _underlyingTokenDecimals = MockERC20(underlyingDealToken).decimals();
            uint256 _numerator;
            /*
            (_success, _numerator) = SafeMath.tryMul(_purchaseTokenPerDealToken, _underlyingDealTokenTotal);
            uint256 _totalIntendedRaise = _numerator / 10**_underlyingTokenDecimals;
            if (_totalIntendedRaise == 0) {
                _success = false;
            }
            */
        /*
            unchecked {
                _numerator = _purchaseTokenPerDealToken * _underlyingDealTokenTotal;
                uint256 _totalIntendedRaise = _numerator / 10**_underlyingTokenDecimals;
                if (
                    _numerator >= _purchaseTokenPerDealToken &&
                    _numerator >= _underlyingDealTokenTotal &&
                    _totalIntendedRaise > 0
                ) {
                    _success = true;
                } else {
                    _success = false;
                }
            }
            */
        /*
            if (!_success || _purchaseRaiseMinimum > _totalIntendedRaise) {
                vm.expectRevert();
            } else {
                require(_purchaseRaiseMinimum <= _totalIntendedRaise, "raise minimum is greater than deal total");
            } 
            */
        /*
        } else {
            _success = true;
        }
        */
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

        /*
        if (!_success) {
            vm.expectRevert();
        */
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
        (, _tempBool) = AelinUpFrontDeal(dealAddress).getAllowList(address(0));
        assertFalse(_tempBool);

        // test nft gating
        (, , _tempBool) = AelinUpFrontDeal(dealAddress).getNftGatingDetails(address(0), address(0), 0);
        assertFalse(_tempBool);
    }

    function testFuzzCreateDealWithNonFullDeposit(
        address _testAddress,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint256 _depositUnderlyingAmount
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
            allowDeallocation: false
        });

        address dealAddress;

        // create when the msg.sender does not have enough underlying tokens to fulfill the _depositUnderlyingAmount
        vm.expectRevert("not enough balance");
        dealAddress = upFrontDealFactory.createUpFrontDeal(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            _depositUnderlyingAmount
        );

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
    }

    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
}
