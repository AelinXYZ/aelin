// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinUpFrontDealFactoryTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);

    AelinUpFrontDealFactory public upFrontDealFactory;
    AelinUpFrontDeal public testUpFrontDeal;
    AelinFeeEscrow public testEscrow;
    MockERC20 public purchaseToken;
    MockERC20 public dealToken;

    address[] public allowListAddresses;
    uint256[] public allowListAmounts;
    IAelinPool.NftCollectionRules[] public nftCollectionRules;

    function setUp() public {
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);
        purchaseToken = new MockERC20("MockPool", "MP");
        dealToken = new MockERC20("MockDeal", "MD");

        deal(address(dealToken), address(this), 1e75);
        deal(address(purchaseToken), address(this), 1e75);
    }

    function testPoolCreateUpFrontDeal() public {
        IAelinUpFrontDeal.UpFrontPool memory poolData;
        poolData = IAelinUpFrontDeal.UpFrontPool({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        IAelinUpFrontDeal.UpFrontDeal memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDeal({
            underlyingDealToken: address(dealToken),
            underlyingDealTokenTotal: 1e35,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 20 days,
            proRataRedemptionPeriod: 30 days,
            holder: address(this),
            maxDealTotalSupply: 1e25
        });

        // the return address of `createUpFrontDeal` - `upFrontDealAddress`
        IERC20(dealToken).approve(address(0xdd36aa107BcA36Ba4606767D873B13B4770F3b12), 1e25);
        address upFrontDealAddress = AelinUpFrontDealFactory(upFrontDealFactory).createUpFrontDeal(poolData, dealData, 1e25);

        (
            string memory _name,
            string memory _symbol,
            uint256 _purchaseTokenCap,
            address _purchaseToken,
            uint256 _sponsorFee,
            uint256 _purchaseDuration
        ) = AelinUpFrontDeal(upFrontDealAddress).poolData();

        assertEq(_name, poolData.name);
        assertEq(_symbol, poolData.symbol);
        assertEq(_purchaseTokenCap, poolData.purchaseTokenCap);
        assertEq(_purchaseToken, poolData.purchaseToken);
        assertEq(_sponsorFee, poolData.sponsorFee);
        assertEq(_purchaseDuration, poolData.purchaseDuration);
    }

    function testDealCreateUpFrontDeal() public {
        IAelinUpFrontDeal.UpFrontPool memory poolData;
        poolData = IAelinUpFrontDeal.UpFrontPool({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });

        IAelinUpFrontDeal.UpFrontDeal memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDeal({
            underlyingDealToken: address(dealToken),
            underlyingDealTokenTotal: 1e35,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 20 days,
            proRataRedemptionPeriod: 30 days,
            holder: address(this),
            maxDealTotalSupply: 1e25
        });

        // the return address of `createUpFrontDeal` - `upFrontDealAddress`
        IERC20(dealToken).approve(address(0xdd36aa107BcA36Ba4606767D873B13B4770F3b12), 1e25);
        address upFrontDealAddress = AelinUpFrontDealFactory(upFrontDealFactory).createUpFrontDeal(poolData, dealData, 1e25);

        (
            address _underlyingDealToken,
            uint256 _underlyingDealTokenTotal,
            uint256 _vestingPeriod,
            uint256 _vestingCliffPeriod,
            uint256 _proRataRedemptionPeriod,
            address _holder,
            uint256 _maxDealTotalSupply
        ) = AelinUpFrontDeal(upFrontDealAddress).dealData();

        assertEq(_underlyingDealToken, dealData.underlyingDealToken);
        assertEq(_underlyingDealTokenTotal, dealData.underlyingDealTokenTotal);
        assertEq(_vestingPeriod, dealData.vestingPeriod);
        assertEq(_vestingCliffPeriod, dealData.vestingCliffPeriod);
        assertEq(_proRataRedemptionPeriod, dealData.proRataRedemptionPeriod);
        assertEq(_holder, dealData.holder);
        assertEq(_maxDealTotalSupply, dealData.maxDealTotalSupply);
    }
}
