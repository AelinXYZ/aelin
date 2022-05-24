// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinUpFrontDealTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    AelinPool public testPool;
    AelinDeal public testDeal;
    AelinUpFrontDeal public testUpFrontDeal;
    AelinUpFrontDealFactory public upFrontFactory;
    AelinFeeEscrow public testEscrow;
    MockERC20 public purchaseToken;
    MockERC20 public dealToken;
    // MockERC721 public collectionAddress1;
    // MockERC721 public collectionAddress2;
    // MockERC1155 public collectionAddress3;
    // MockERC1155 public collectionAddress4;

    // address public poolAddress;
    address public upFrontDeal;
    address[] public allowListAddresses;
    uint256[] public allowListAmounts;

    function setUp() public {
        testPool = new AelinPool();
        testDeal = new AelinDeal();
        testEscrow = new AelinFeeEscrow();
        testUpFrontDeal = new AelinUpFrontDeal();
        upFrontFactory = new AelinUpFrontDealFactory(
            address(testPool),
            address(testDeal),
            aelinTreasury,
            address(testEscrow),
            address(testUpFrontDeal)
        );
        purchaseToken = new MockERC20("MockPool", "MP");
        dealToken = new MockERC20("MockDeal", "MD");
        // collectionAddress1 = new MockERC721("TestCollection", "TC");
        // collectionAddress2 = new MockERC721("TestCollection", "TC");
        // collectionAddress3 = new MockERC1155("");
        // collectionAddress4 = new MockERC1155("");

        deal(address(dealToken), address(this), 1e75);

        IAelinPool.PoolData memory poolData;
        IAelinDeal.DealData memory dealData;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRules
        });
        dealData = IAelinDeal.DealData({
            underlyingDealToken: address(dealToken),
            underlyingDealTokenTotal: 1e35,
            vestingPeriod: 10 days,
            vestingCliffPeriod: 20 days,
            proRataRedemptionPeriod: 30 days,
            openRedemptionPeriod: 0,
            holder: address(this),
            maxDealTotalSupply: 1e25,
            holderFundingDuration: 10 days
        });

        IERC20(dealToken).approve(address(testUpFrontDeal), type(uint256).max);
        AelinUpFrontDeal(testUpFrontDeal).initializeUpFrontDeal(
            poolData.name,
            poolData.symbol,
            dealData,
            1e35,
            address(upFrontFactory)
        );

        assertEq(upFrontFactory.AELIN_POOL_LOGIC(), address(testPool));
        assertEq(upFrontFactory.AELIN_DEAL_LOGIC(), address(testDeal));
        assertEq(upFrontFactory.AELIN_TREASURY(), address(aelinTreasury));
        assertEq(upFrontFactory.AELIN_ESCROW_LOGIC(), address(testEscrow));
    }

    function testInitializeUpFrontDeal() public {
        (uint256 proRataPeriod, , ) = AelinDeal(testUpFrontDeal).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(testUpFrontDeal).openRedemption();

        assertEq(AelinDeal(testUpFrontDeal).name(), "aeDeal-POOL");
        assertEq(AelinDeal(testUpFrontDeal).symbol(), "aeD-POOL");
        assertEq(AelinDeal(testUpFrontDeal).decimals(), 18);
        assertEq(AelinDeal(testUpFrontDeal).holder(), address(this));
        assertEq(AelinDeal(testUpFrontDeal).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(testUpFrontDeal).underlyingDealTokenTotal(), 1e35);
        assertEq(AelinDeal(testUpFrontDeal).maxTotalSupply(), 1e25);
        assertEq(AelinDeal(testUpFrontDeal).aelinPool(), address(this));
        assertEq(AelinDeal(testUpFrontDeal).vestingCliffPeriod(), 20 days);
        assertEq(AelinDeal(testUpFrontDeal).vestingPeriod(), 10 days);
        assertEq(proRataPeriod, 30 days);
        assertEq(openPeriod, 0);
        assertEq(AelinDeal(testUpFrontDeal).holderFundingExpiry(), 10 days);
        assertEq(AelinDeal(testUpFrontDeal).aelinTreasuryAddress(), address(aelinTreasury));
        assertEq(
            AelinDeal(testUpFrontDeal).underlyingPerDealExchangeRate(),
            (1e35 * 1e18) / AelinDeal(testUpFrontDeal).maxTotalSupply()
        );
        assertTrue(AelinDeal(testUpFrontDeal).depositComplete());
    }
}
