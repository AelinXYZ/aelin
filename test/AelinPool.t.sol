// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import {AelinPool} from "../contracts/AelinPool.sol";
import {AelinDeal} from "../contracts/AelinDeal.sol";
import {AelinPoolFactory} from "../contracts/AelinPoolFactory.sol";
import {IAelinDeal} from "../contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "../contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinPoolTest is DSTest {
    address public aelinRewards = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public poolAddress;

    AelinPool public pool;
    AelinDeal public deal;
    AelinPoolFactory public poolFactory;
    Vm public vm = Vm(HEVM_ADDRESS);

    MockERC20 public dealToken;
    MockERC20 public purchaseToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;

    using stdStorage for StdStorage;
    StdStorage public stdstore;

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function setUp() public {
        pool = new AelinPool();
        deal = new AelinDeal();
        poolFactory = new AelinPoolFactory(address(pool), address(deal), aelinRewards);
        dealToken = new MockERC20("MockDeal", "MD");
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");

        writeTokenBalance(address(this), address(purchaseToken), 1e75);

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftData[] memory nftData = new IAelinPool.NftData[](2);

        nftData[0].collectionAddress = address(collectionAddress1);
        nftData[0].purchaseAmount = 1e22;
        nftData[0].purchaseAmountPerToken = true;

        nftData[1].collectionAddress = address(collectionAddress2);
        nftData[1].purchaseAmount = 0;
        nftData[1].purchaseAmountPerToken = false;

        IAelinPool.PoolData memory poolData;
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
            nftData: nftData
        });

        poolAddress = poolFactory.createPool(poolData);

        purchaseToken.approve(address(poolAddress), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            initialize
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e35);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(deal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(AelinPool(poolAddress).hasNftList());
    }

    /*//////////////////////////////////////////////////////////////
                          purchasePoolTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzzPurchasePoolTokens(uint256 purchaseTokenAmount, uint256 timestamp) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(timestamp < 20 days);
        assertTrue(!AelinPool(poolAddress).hasAllowList());

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        vm.warp(block.timestamp + timestamp);
        AelinPool(poolAddress).purchasePoolTokens(purchaseTokenAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseTokenAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseTokenAmount);
        if (purchaseTokenAmount == 1e27) assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + timestamp);
        assertEq(AelinPool(poolAddress).totalSupply(), AelinPool(poolAddress).balanceOf(address(this)));
    }

    function testFuzzMultiplePurchasePoolTokens(uint256 purchaseTokenAmount, uint256 numberOfTimes) public {
        vm.assume(purchaseTokenAmount <= 1e27);
        vm.assume(numberOfTimes <= 1000);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));
        uint256 purchaseTokenTotal;

        for (uint256 i; i < numberOfTimes; ) {
            purchaseTokenTotal += purchaseTokenAmount;
            AelinPool(poolAddress).purchasePoolTokens(purchaseTokenAmount);

            assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseTokenTotal);
            assertEq(
                IERC20(purchaseToken).balanceOf(address(poolAddress)),
                balanceOfPoolBeforePurchase + purchaseTokenTotal
            );
            if (purchaseTokenAmount == 1e27) assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp);
            assertEq(AelinPool(poolAddress).totalSupply(), AelinPool(poolAddress).balanceOf(address(this)));

            unchecked {
                ++i;
            }
        }
    }

    // TODO (testPurchasePoolTokensWithAllowList)

    /*//////////////////////////////////////////////////////////////
                       purchaseScenario1and2
    //////////////////////////////////////////////////////////////*/

    function testPurchaseScenario1and2(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress1), purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), purchaseAmount);
    }

    function testFailPurchaseScenario1and2(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e22);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress1), purchaseAmount);
    }

    function testFailMultiplePurchaseScenario1and2(uint256 purchaseAmount) public {
        // 1e22 / 2 = 5e21
        vm.assume(purchaseAmount > 5e21);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress1), purchaseAmount);
        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress1), purchaseAmount);
    }

    function testFailPurchaseScenario1and2WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress1), purchaseAmount);
    }

    function testUnlimitedPurchaseScenario1and2(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(purchaseAmount <= 1e75);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress2).mint(address(this), 1);

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolScenario1and2for721(address(collectionAddress2), purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertEq(AelinPool(poolAddress).nftAllowList(address(this)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                         purchaseScenario3
    //////////////////////////////////////////////////////////////*/

    function testPurchaseScenario3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + purchaseAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount);
        assertTrue(AelinPool(poolAddress).nftIdUsedForPurchase(address(collectionAddress1), 1));
    }

    function testPurchaseMultipleScenario3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);
        MockERC721(collectionAddress1).mint(address(this), 2);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256 balanceOfPoolBeforePurchase = IERC20(purchaseToken).balanceOf(address(poolAddress));

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);

        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount * 2);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), balanceOfPoolBeforePurchase + (purchaseAmount * 2));
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - (purchaseAmount * 2));
        assertTrue(AelinPool(poolAddress).nftIdUsedForPurchase(address(collectionAddress1), 1));
        assertTrue(AelinPool(poolAddress).nftIdUsedForPurchase(address(collectionAddress1), 2));
    }

    function testFailPurchaseMultipleScenario3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount <= 1e22);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    function testFailPurchaseScenario3(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 1e22);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    function testFailMultiplePurchaseScenario3(uint256 purchaseAmount) public {
        // 1e22 / 2 = 5e21
        vm.assume(purchaseAmount > 5e21);
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);
        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    function testFailPurchaseScenario3WithoutNft(uint256 purchaseAmount) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(purchaseAmount < type(uint256).max);
        assertTrue(AelinPool(poolAddress).hasNftList());

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, purchaseAmount);
    }

    function testFailTransferNftAndPurchase() public {
        assertTrue(AelinPool(poolAddress).hasNftList());

        MockERC721(collectionAddress1).mint(address(this), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, 1e22);

        MockERC721(collectionAddress1).transferFrom(address(this), address(0xBEEF), 1);
        writeTokenBalance(address(0xBEEF), address(purchaseToken), 1e75);

        vm.prank(address(0xBEEF));
        AelinPool(poolAddress).purchasePoolScenario3for721(address(collectionAddress1), tokenIds, 1e22);
    }

    /*//////////////////////////////////////////////////////////////
                            createDeal
    //////////////////////////////////////////////////////////////*/

    function testCreateDeal() public {
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            1e27,
            1e27,
            10 days,
            20 days,
            30 days,
            0,
            address(this),
            30 days
        );

        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinPool(poolAddress).numberOfDeals(), 1);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp);
        assertEq(AelinPool(poolAddress).holder(), address(this));
        assertEq(AelinPool(poolAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinPool(poolAddress).purchaseTokenTotalForDeal(), 1e27);
        assertEq(AelinDeal(dealAddress).holder(), address(this));
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), 1e27);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e27);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), 20 days);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), 10 days);
        assertEq(proRataPeriod, 30 days);
        assertEq(openPeriod, 0);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinDeal(dealAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (1e27 * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testFuzzCreateDealDuration(uint256 holderFundingDuration, uint256 proRataRedemptionPeriod) public {
        vm.assume(holderFundingDuration >= 30 minutes);
        vm.assume(holderFundingDuration <= 30 days);
        vm.assume(proRataRedemptionPeriod >= 30 minutes);
        vm.assume(proRataRedemptionPeriod <= 30 days);

        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            1e27,
            1e27,
            0,
            0,
            proRataRedemptionPeriod,
            0,
            address(this),
            holderFundingDuration
        );

        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinPool(poolAddress).numberOfDeals(), 1);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp);
        assertEq(AelinPool(poolAddress).holder(), address(this));
        assertEq(AelinPool(poolAddress).holderFundingExpiry(), block.timestamp + holderFundingDuration);
        assertEq(AelinPool(poolAddress).purchaseTokenTotalForDeal(), 1e27);
        assertEq(AelinDeal(dealAddress).holder(), address(this));
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), 1e27);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e27);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), 0);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), 0);
        assertEq(proRataPeriod, proRataRedemptionPeriod);
        assertEq(openPeriod, 0);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + holderFundingDuration);
        assertEq(AelinDeal(dealAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (1e27 * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testFuzzCreateDealVesting(uint256 vestingCliffPeriod, uint256 vestingPeriod) public {
        vm.assume(vestingPeriod <= 1825 days);
        vm.assume(vestingCliffPeriod <= 1825 days);

        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            1e27,
            1e27,
            vestingPeriod,
            vestingCliffPeriod,
            30 days,
            0,
            address(this),
            30 days
        );

        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinPool(poolAddress).numberOfDeals(), 1);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp);
        assertEq(AelinPool(poolAddress).holder(), address(this));
        assertEq(AelinPool(poolAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinPool(poolAddress).purchaseTokenTotalForDeal(), 1e27);
        assertEq(AelinDeal(dealAddress).holder(), address(this));
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), 1e27);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e27);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), vestingCliffPeriod);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), vestingPeriod);
        assertEq(proRataPeriod, 30 days);
        assertEq(openPeriod, 0);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinDeal(dealAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (1e27 * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testFuzzCreateDealTokenTotal(
        uint256 purchaseTokenTotalForDeal,
        uint256 underlyingDealTokenTotal,
        uint256 openRedemptionPeriod
    ) public {
        vm.assume(purchaseTokenTotalForDeal > 0);
        vm.assume(purchaseTokenTotalForDeal <= 1e27);
        vm.assume(underlyingDealTokenTotal > 0);
        vm.assume(underlyingDealTokenTotal <= 1e35);
        if (purchaseTokenTotalForDeal == 1e27) vm.assume(openRedemptionPeriod == 0);
        vm.assume(openRedemptionPeriod >= 30 minutes);
        vm.assume(openRedemptionPeriod <= 30 days);

        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            purchaseTokenTotalForDeal,
            underlyingDealTokenTotal,
            20 days,
            20 days,
            20 days,
            openRedemptionPeriod,
            address(this),
            30 days
        );

        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinPool(poolAddress).numberOfDeals(), 1);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp);
        assertEq(AelinPool(poolAddress).holder(), address(this));
        assertEq(AelinPool(poolAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinPool(poolAddress).purchaseTokenTotalForDeal(), purchaseTokenTotalForDeal);
        assertEq(AelinDeal(dealAddress).holder(), address(this));
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), underlyingDealTokenTotal);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), purchaseTokenTotalForDeal);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), 20 days);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), 20 days);
        assertEq(proRataPeriod, 20 days);
        assertEq(openPeriod, openRedemptionPeriod);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinDeal(dealAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (underlyingDealTokenTotal * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testFailCreateDeal() public {
        vm.prank(address(0x1337));

        pool.createDeal(address(dealToken), 1e27, 1e27, 10 days, 20 days, 30 days, 0, address(this), 30 days);
    }

    /*//////////////////////////////////////////////////////////////
                            maxDealAccept
    //////////////////////////////////////////////////////////////*/

    function testMaxDealAccept() public {
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        AelinPool(poolAddress).createDeal(
            address(dealToken),
            1e27,
            1e27,
            10 days,
            20 days,
            30 days,
            0,
            address(this),
            30 days
        );

        uint256 maxDeal = AelinPool(poolAddress).maxDealAccept(address(this));

        assertEq(maxDeal, 0);

        // TODO (Additional checks if required)
    }

    /*//////////////////////////////////////////////////////////////
                              sponsor
    //////////////////////////////////////////////////////////////*/

    function testFuzzSetSponsor(address futureSponsor) public {
        AelinPool(poolAddress).setSponsor(futureSponsor);
        assertEq(AelinPool(poolAddress).futureSponsor(), futureSponsor);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
    }

    function testFailSetSponsor() public {
        vm.prank(address(0x1337));
        AelinPool(poolAddress).setSponsor(msg.sender);
        assertEq(AelinPool(poolAddress).futureSponsor(), msg.sender);
    }

    function testFuzzAcceptSponsor(address futureSponsor) public {
        AelinPool(poolAddress).setSponsor(futureSponsor);
        vm.prank(address(futureSponsor));
        AelinPool(poolAddress).acceptSponsor();
        assertEq(AelinPool(poolAddress).sponsor(), address(futureSponsor));
    }

    /*//////////////////////////////////////////////////////////////
                          acceptDealTokens
    //////////////////////////////////////////////////////////////*/

    // TODO

    /*//////////////////////////////////////////////////////////////
                          maxProRataAmount
    //////////////////////////////////////////////////////////////*/

    // TODO

    /*//////////////////////////////////////////////////////////////
                          withdrawfromPool
    //////////////////////////////////////////////////////////////*/

    function testWithdrawMaxFromPool() public {
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 50 days);

        AelinPool(poolAddress).withdrawMaxFromPool();

        assertEq(AelinPool(poolAddress).amountWithdrawn(address(this)), 1e27);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), 1e27);
        assertEq(AelinPool(poolAddress).balanceOf(address(this)), 0);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 0);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75);
    }

    function testWithdrawFromPool() public {
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 50 days);
        AelinPool(poolAddress).withdrawFromPool(1e20);

        assertEq(AelinPool(poolAddress).amountWithdrawn(address(this)), 1e20);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), 1e20);
        assertEq(AelinPool(poolAddress).balanceOf(address(this)), 1e27 - 1e20);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 1e27 - 1e20);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - 1e27 + 1e20);
    }

    function testFuzzWithdrawMaxFromPool(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= 1e27);
        AelinPool(poolAddress).purchasePoolTokens(amount);

        vm.warp(block.timestamp + 50 days);
        AelinPool(poolAddress).withdrawMaxFromPool();

        assertEq(AelinPool(poolAddress).amountWithdrawn(address(this)), amount);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), amount);
        assertEq(AelinPool(poolAddress).balanceOf(address(this)), 0);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 0);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75);
    }

    function testFuzzWithdrawFromPool(uint256 purchaseAmount, uint256 withdrawAmount) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(withdrawAmount > 0);
        vm.assume(purchaseAmount <= 1e27);
        vm.assume(withdrawAmount <= purchaseAmount);
        AelinPool(poolAddress).purchasePoolTokens(purchaseAmount);

        vm.warp(block.timestamp + 50 days);
        AelinPool(poolAddress).withdrawFromPool(withdrawAmount);

        assertEq(AelinPool(poolAddress).amountWithdrawn(address(this)), withdrawAmount);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), withdrawAmount);
        assertEq(AelinPool(poolAddress).balanceOf(address(this)), purchaseAmount - withdrawAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), purchaseAmount - withdrawAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - purchaseAmount + withdrawAmount);
    }

    function testFailWithdrawFromPool() public {
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 50 days);
        vm.prank(address(0xBEEF));
        AelinPool(poolAddress).withdrawFromPool(1e27);
    }

    function testFuzzWithdrawMaxDiffAddress(uint256 purchaseAmount, address testAddress) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(purchaseAmount <= 1e27);
        vm.assume(testAddress != address(0));

        vm.startPrank(testAddress);
        writeTokenBalance(testAddress, address(purchaseToken), 1e75);
        purchaseToken.approve(address(poolAddress), type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(purchaseAmount);

        vm.warp(block.timestamp + 50 days);
        AelinPool(poolAddress).withdrawMaxFromPool();

        assertEq(AelinPool(poolAddress).amountWithdrawn(testAddress), purchaseAmount);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), purchaseAmount);
        assertEq(AelinPool(poolAddress).balanceOf(testAddress), 0);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 0);
        assertEq(IERC20(purchaseToken).balanceOf(testAddress), 1e75);
        vm.stopPrank();
    }

    function testFuzzWithdrawDiffAddress(
        uint256 purchaseAmount,
        uint256 withdrawAmount,
        address testAddress
    ) public {
        vm.assume(purchaseAmount > 0);
        vm.assume(withdrawAmount > 0);
        vm.assume(purchaseAmount <= 1e27);
        vm.assume(withdrawAmount <= purchaseAmount);
        vm.assume(testAddress != address(0));

        vm.startPrank(testAddress);
        writeTokenBalance(testAddress, address(purchaseToken), 1e75);
        purchaseToken.approve(address(poolAddress), type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(purchaseAmount);

        vm.warp(block.timestamp + 50 days);
        AelinPool(poolAddress).withdrawFromPool(withdrawAmount);

        assertEq(AelinPool(poolAddress).amountWithdrawn(testAddress), withdrawAmount);
        assertEq(AelinPool(poolAddress).totalAmountWithdrawn(), withdrawAmount);
        assertEq(AelinPool(poolAddress).balanceOf(testAddress), purchaseAmount - withdrawAmount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), purchaseAmount - withdrawAmount);
        assertEq(IERC20(purchaseToken).balanceOf(testAddress), 1e75 - purchaseAmount + withdrawAmount);
        vm.stopPrank();
    }
}
