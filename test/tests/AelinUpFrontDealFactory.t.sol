// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
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

    IAelinUpFrontDeal.UpFrontDeal public dealData;
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
        //vm.assume(_purchaseRaiseMinimum == 0);
        /*
        if (_purchaseRaiseMinimum > 0) {
            uint8 _underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
            uint256 _numerator = _dealConfig.purchaseTokenPerDealToken * _dealConfig.underlyingDealTokenTotal;
            
            uint256 _totalIntendedRaise = (_dealConfig.purchaseTokenPerDealToken * _dealConfig.underlyingDealTokenTotal) /
                10**_underlyingTokenDecimals;
            require(_dealConfig.purchaseRaiseMinimum <= _totalIntendedRaise, "raise minimum is greater than deal total");
        }
        */
        vm.assume(_purchaseDuration >= 30 minutes);
        vm.assume(_purchaseDuration <= 30 days);
        vm.assume(_vestingCliffPeriod <= 1825 days);
        vm.assume(_vestingPeriod <= 1825 days);

        AelinNftGating.NftCollectionRules[] memory _nftCollectionRules;
        AelinAllowList.InitData memory _allowListInit;

        IAelinUpFrontDeal.UpFrontDeal memory _dealData;
        _dealData = IAelinUpFrontDeal.UpFrontDeal({
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

        //assertEq(keccak256(abi.encode(AelinUpFrontDeal(dealAddress).dealData)), keccak256(abi.encode(_dealData)));
        assertEq(AelinUpFrontDeal(dealAddress).dealFactory(), address(upFrontDealFactory));
        assertEq(AelinUpFrontDeal(dealAddress).name(), "aeUpFrontDeal-DEAL");
        assertEq(AelinUpFrontDeal(dealAddress).symbol(), "aeUD-DEAL");
    }
}
