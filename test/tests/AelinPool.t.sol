// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICryptoPunks} from "contracts/interfaces/ICryptoPunks.sol";

contract AelinPoolTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    AelinPoolFactory public poolFactory;
    AelinDeal public testDeal;

    MockERC20 public dealToken;
    MockERC20 public purchaseToken;
    MockERC721 public collectionAddress1;
    MockERC721 public collectionAddress2;
    MockERC721 public collectionAddress3;

    event Vouch(address indexed voucher);
    event Disavow(address indexed voucher);

    function setUp() public {
        testDeal = new AelinDeal();
        poolFactory = new AelinPoolFactory(
            address(new AelinPool()),
            address(testDeal),
            aelinTreasury,
            address(new AelinFeeEscrow())
        );
        dealToken = new MockERC20("MockDeal", "MD");
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddress1 = new MockERC721("TestCollection", "TC");
        collectionAddress2 = new MockERC721("TestCollection", "TC");
        collectionAddress3 = new MockERC721("TestCollection", "TC");

        deal(address(purchaseToken), address(this), 1e75);
        deal(address(dealToken), address(this), 1e75);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        address[] memory allowListAddresses = new address[](2);
        uint256[] memory allowListAmounts = new uint256[](2);

        allowListAddresses[0] = address(0x1337);
        allowListAmounts[0] = 1e22;
        allowListAddresses[1] = address(0x1338);
        allowListAmounts[1] = 3e22;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](3);

        nftCollectionRules[0].collectionAddress = address(collectionAddress1);
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        nftCollectionRules[1].collectionAddress = address(collectionAddress2);
        nftCollectionRules[1].purchaseAmount = 1e22;
        nftCollectionRules[1].purchaseAmountPerToken = false;

        nftCollectionRules[2].collectionAddress = address(collectionAddress3);
        nftCollectionRules[2].purchaseAmount = 1e22;
        nftCollectionRules[2].purchaseAmountPerToken = true;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        IAelinPool.PoolData memory poolDataWithAllowList;
        poolDataWithAllowList = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        IAelinPool.PoolData memory poolDataWith721;
        poolDataWith721 = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e35,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        poolAddress = poolFactory.createPool(poolData);
        poolAddressWithAllowList = poolFactory.createPool(poolDataWithAllowList);
        poolAddressWith721 = poolFactory.createPool(poolDataWith721);

        purchaseToken.approve(address(poolAddress), type(uint256).max);
        purchaseToken.approve(address(poolAddressWith721), type(uint256).max);
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
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddress).aelinTreasuryAddress(), address(aelinTreasury));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
        assertTrue(!AelinPool(poolAddress).hasNftList());

        assertEq(AelinPool(poolAddressWith721).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddressWith721).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddressWith721).decimals(), 18);
        assertEq(AelinPool(poolAddressWith721).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddressWith721).purchaseTokenCap(), 1e35);
        assertEq(AelinPool(poolAddressWith721).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddressWith721).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddressWith721).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddressWith721).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddressWith721).sponsor(), address(this));
        assertEq(AelinPool(poolAddressWith721).aelinDealLogicAddress(), address(testDeal));
        assertEq(AelinPool(poolAddressWith721).aelinTreasuryAddress(), address(aelinTreasury));
        assertTrue(!AelinPool(poolAddressWith721).hasAllowList());
        assertTrue(AelinPool(poolAddressWith721).hasNftList());
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
        assertEq(AelinDeal(dealAddress).aelinTreasuryAddress(), address(aelinTreasury));
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
        assertEq(AelinDeal(dealAddress).aelinTreasuryAddress(), address(aelinTreasury));
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
        assertEq(AelinDeal(dealAddress).aelinTreasuryAddress(), address(aelinTreasury));
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
        assertEq(AelinDeal(dealAddress).aelinTreasuryAddress(), address(aelinTreasury));
        assertEq(
            AelinDeal(dealAddress).underlyingPerDealExchangeRate(),
            (underlyingDealTokenTotal * 1e18) / AelinDeal(dealAddress).maxTotalSupply()
        );
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testFailCreateDeal() public {
        vm.prank(address(0x1337));

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
        vm.assume(futureSponsor != address(0));
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
        vm.assume(futureSponsor != address(0));
        AelinPool(poolAddress).setSponsor(futureSponsor);
        vm.prank(address(futureSponsor));
        AelinPool(poolAddress).acceptSponsor();
        assertEq(AelinPool(poolAddress).sponsor(), address(futureSponsor));
    }

    /*//////////////////////////////////////////////////////////////
                              vouch
    //////////////////////////////////////////////////////////////*/

    function testFuzzVouchForPool(address attestant) public {
        vm.prank(attestant);
        vm.expectEmit(false, false, false, false, address(poolAddress));
        emit Vouch(attestant);
        AelinPool(poolAddress).vouch();
    }

    /*//////////////////////////////////////////////////////////////
                              disavow
    //////////////////////////////////////////////////////////////*/

    function testFuzzDisavowForPool(address attestant) public {
        vm.prank(attestant);
        vm.expectEmit(false, false, false, false, address(poolAddress));
        emit Disavow(attestant);
        AelinPool(poolAddress).disavow();
    }

    /*//////////////////////////////////////////////////////////////
                          acceptDealTokens
    //////////////////////////////////////////////////////////////*/

    function testAcceptMaxDealTokens() public {
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

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e27);

        AelinPool(poolAddress).acceptMaxDealTokens();

        assertEq(IERC20(dealToken).balanceOf(dealAddress), 1e27 - ((1e27 * 2e18) / 100e18));
        assertEq(IERC20(dealToken).balanceOf(address(AelinDeal(dealAddress).aelinFeeEscrow())), 1e25 * 2);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 0);
        assertEq(IERC20(poolAddress).balanceOf(address(this)), 0);
        assertEq(AelinPool(poolAddress).amountAccepted(address(this)), 1e27);
        assertEq(AelinPool(poolAddress).totalAmountAccepted(), 1e27);
        assertTrue(!AelinPool(poolAddress).openPeriodEligible(address(this)));
    }

    // accept max deal after proRata and open period - fail
    function testFailAcceptMaxDealTokens(uint256 timestamp) public {
        vm.assume(timestamp > 30 days);
        vm.assume(timestamp < type(uint256).max);
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

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e27);

        vm.warp(block.timestamp + 20 days + timestamp);
        AelinPool(poolAddress).acceptMaxDealTokens();
    }

    function testAcceptDealTokens(uint256 amount) public {
        vm.assume(amount < 1e27);
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

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e27);

        AelinPool(poolAddress).acceptDealTokens(amount);

        assertEq(IERC20(dealToken).balanceOf(dealAddress), 1e27 - ((amount * 2e18) / 100e18));
        assertEq(IERC20(dealToken).balanceOf(address(AelinDeal(dealAddress).aelinFeeEscrow())), (amount * 2e18) / 100e18);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - 1e27 + amount);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 1e27 - amount);
        assertEq(IERC20(poolAddress).balanceOf(address(this)), 1e27 - amount);
        assertEq(AelinPool(poolAddress).amountAccepted(address(this)), amount);
        assertEq(AelinPool(poolAddress).totalAmountAccepted(), amount);
        assertTrue(!AelinPool(poolAddress).openPeriodEligible(address(this)));
    }

    function testAcceptDealTokensLessThanPurchase() public {
        AelinPool(poolAddress).purchasePoolTokens(1e30);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            1e27,
            1e15,
            10 days,
            20 days,
            30 days,
            30 days,
            address(this),
            30 days
        );

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e15);

        AelinPool(poolAddress).acceptDealTokens(1e25);

        assertEq(IERC20(poolAddress).balanceOf(address(this)), 1e30 - 1e25);
        assertEq(IERC20(dealAddress).balanceOf(address(this)), 1e25 - ((1e25 * 2e18) / 100e18));
        // ((acceptedDealAmount * aelinFees) * (underlyingDealAmount * 1e18 / maxSupply)) / 1e18
        assertEq(IERC20(dealToken).balanceOf(address(AelinDeal(dealAddress).aelinFeeEscrow())), 2e11);
        assertEq(IERC20(dealToken).balanceOf(address(dealAddress)), 1e15 - 2e11);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - 1e30 + 1e25);
        assertEq(IERC20(purchaseToken).balanceOf(address(poolAddress)), 1e30 - 1e25);
        assertEq(AelinPool(poolAddress).amountAccepted(address(this)), 1e25);
        assertEq(AelinPool(poolAddress).totalAmountAccepted(), 1e25);
        assertTrue(!AelinPool(poolAddress).openPeriodEligible(address(this)));
    }

    // TODO (additional tests)

    /*//////////////////////////////////////////////////////////////
                          maxProRataAmount
    //////////////////////////////////////////////////////////////*/

    function testMaxProRataAmount(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= 1e27);
        AelinPool(poolAddress).purchasePoolTokens(amount);

        vm.warp(block.timestamp + 20 days);
        address dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken),
            amount,
            1e27,
            10 days,
            20 days,
            30 days,
            0,
            address(this),
            30 days
        );

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e27);

        uint256 proRataAmount = AelinPool(poolAddress).maxProRataAmount(address(this));

        assertEq(proRataAmount, amount);
    }

    function testMaxProRataAmountWithoutPurchase() public {
        deal(address(purchaseToken), address(0xBEEF), 1e75);
        vm.startPrank(address(0xBEEF));
        IERC20(purchaseToken).approve(address(poolAddress), type(uint256).max);
        AelinPool(poolAddress).purchasePoolTokens(1e27);
        vm.stopPrank();

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

        IERC20(dealToken).approve(address(dealAddress), type(uint256).max);
        AelinDeal(dealAddress).depositUnderlying(1e27);

        uint256 proRataAmount = AelinPool(poolAddress).maxProRataAmount(address(this));

        assertEq(proRataAmount, 0);
    }

    // TODO (additional tests)

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
        deal(address(purchaseToken), testAddress, 1e75);
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
        deal(address(purchaseToken), testAddress, 1e75);
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
