// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import {AelinDeal} from "../contracts/AelinDeal.sol";
import {AelinPool} from "../contracts/AelinPool.sol";
import {AelinPoolFactory} from "../contracts/AelinPoolFactory.sol";
import {IAelinDeal} from "../contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "../contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinDealTest is DSTest {

    address public aelinRewards = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public poolAddress;
    address public dealAddress;

    AelinPool public pool;
    AelinDeal public deal;
    AelinPoolFactory public poolFactory;
    Vm public vm = Vm(HEVM_ADDRESS);

    MockERC20 public dealToken;
    MockERC20 public purchaseToken;

    using stdStorage for StdStorage;
    StdStorage public stdstore;

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function setUp() public {
        pool = new AelinPool();
        deal = new AelinDeal();
        poolFactory = new AelinPoolFactory(address(pool), address(deal), aelinRewards);
        dealToken = new MockERC20("MockDeal", "MD");
        purchaseToken = new MockERC20("MockPool", "MP");

        writeTokenBalance(address(this), address(purchaseToken), 1e75);
        writeTokenBalance(address(this), address(dealToken), 1e75);

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftData[] memory nftData;

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
        AelinPool(poolAddress).purchasePoolTokens(1e27);

        vm.warp(block.timestamp + 20 days);
        dealAddress = AelinPool(poolAddress).createDeal(
            address(dealToken), 
            1e25, 
            1e35, 
            10 days, 
            20 days, 
            30 days, 
            10 days, 
            address(this), 
            30 days
        );

        dealToken.approve(address(dealAddress), type(uint256).max);
    }

    function testInitialize() public {
        (uint256 proRataPeriod, , ) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, , ) = AelinDeal(dealAddress).openRedemption();

        assertEq(AelinDeal(dealAddress).name(), "aeDeal-POOL");
        assertEq(AelinDeal(dealAddress).symbol(), "aeD-POOL");
        assertEq(AelinDeal(dealAddress).decimals(), 18);
        assertEq(AelinDeal(dealAddress).holder(), address(this));
        assertEq(AelinDeal(dealAddress).underlyingDealToken(), address(dealToken));
        assertEq(AelinDeal(dealAddress).underlyingDealTokenTotal(), 1e35);
        assertEq(AelinDeal(dealAddress).maxTotalSupply(), 1e25);
        assertEq(AelinDeal(dealAddress).aelinPool(), address(poolAddress));
        assertEq(AelinDeal(dealAddress).vestingCliffPeriod(), 20 days);
        assertEq(AelinDeal(dealAddress).vestingPeriod(), 10 days);
        assertEq(proRataPeriod, 30 days);
        assertEq(openPeriod, 10 days);
        assertEq(AelinDeal(dealAddress).holderFundingExpiry(), block.timestamp + 30 days);
        assertEq(AelinDeal(dealAddress).aelinRewardsAddress(), address(aelinRewards));
        assertEq(AelinDeal(dealAddress).underlyingPerDealExchangeRate(), (1e35 * 1e18) / AelinDeal(dealAddress).maxTotalSupply());
        assertTrue(!AelinDeal(dealAddress).depositComplete());
    }

    function testSetHolder(address futureHolder) public {
        AelinDeal(dealAddress).setHolder(futureHolder);
        assertEq(AelinDeal(dealAddress).futureHolder(), address(futureHolder));
        assertEq(AelinDeal(dealAddress).holder(), address(this));
    }

    function testFailSetHolder() public {
        vm.prank(address(0x1337));
        AelinDeal(dealAddress).setHolder(msg.sender);
        assertEq(AelinDeal(dealAddress).futureHolder(), msg.sender);
    }

    function testFuzzAcceptHolder(address futureHolder) public {
        AelinDeal(dealAddress).setHolder(futureHolder);
        vm.prank(address(futureHolder));
        AelinDeal(dealAddress).acceptHolder();
        assertEq(AelinDeal(dealAddress).holder(), address(futureHolder));
    }

    function testDepositUnderlying() public {
        vm.warp(block.timestamp + 10 days);
        bool deposited = AelinDeal(dealAddress).depositUnderlying(1e35);

        (uint256 proRataPeriod, uint256 proRataStart, uint256 proRataExpiry) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, uint256 openStart, uint256 openExpiry) = AelinDeal(dealAddress).openRedemption();

        assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(dealAddress)), 1e35);
        assertTrue(AelinDeal(dealAddress).depositComplete());
        assertEq(proRataPeriod, 30 days);
        assertEq(proRataStart, block.timestamp);
        assertEq(proRataExpiry, block.timestamp + proRataPeriod);
        assertEq(AelinDeal(dealAddress).vestingCliffExpiry(), proRataExpiry + openPeriod + AelinDeal(dealAddress).vestingCliffPeriod());
        assertEq(AelinDeal(dealAddress).vestingExpiry(), AelinDeal(dealAddress).vestingCliffExpiry() + AelinDeal(dealAddress).vestingPeriod());
        assertEq(openStart, proRataExpiry);
        assertEq(openExpiry, proRataExpiry + openPeriod);
        assertTrue(deposited);
    }

    function testFuzzDepositUnderlying(uint256 amount) public {
        vm.assume(amount <= 1e35);
        vm.warp(block.timestamp + 10 days);
        bool deposited = AelinDeal(dealAddress).depositUnderlying(amount);

        (uint256 proRataPeriod, uint256 proRataStart, uint256 proRataExpiry) = AelinDeal(dealAddress).proRataRedemption();
        (uint256 openPeriod, uint256 openStart, uint256 openExpiry) = AelinDeal(dealAddress).openRedemption();

        if(amount == 1e35) {    
            assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - 1e35);
            assertEq(IERC20(dealToken).balanceOf(address(dealAddress)), 1e35);
            assertTrue(AelinDeal(dealAddress).depositComplete());
            assertEq(proRataPeriod, 30 days);
            assertEq(proRataStart, block.timestamp);
            assertEq(proRataExpiry, block.timestamp + proRataPeriod);
            assertEq(AelinDeal(dealAddress).vestingCliffExpiry(), proRataExpiry + openPeriod + AelinDeal(dealAddress).vestingCliffPeriod());
            assertEq(AelinDeal(dealAddress).vestingExpiry(), AelinDeal(dealAddress).vestingCliffExpiry() + AelinDeal(dealAddress).vestingPeriod());
            assertEq(openStart, proRataExpiry);
            assertEq(openExpiry, proRataExpiry + openPeriod);
            assertTrue(deposited);
        }

        assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - amount);
        assertEq(IERC20(dealToken).balanceOf(address(dealAddress)), amount);
        assertTrue(!AelinDeal(dealAddress).depositComplete());
        assertEq(proRataPeriod, 30 days);
        assertEq(proRataStart, 0);
        assertEq(proRataExpiry, 0);
        assertEq(AelinDeal(dealAddress).vestingCliffExpiry(), 0);
        assertEq(AelinDeal(dealAddress).vestingExpiry(), 0);
        assertEq(openPeriod, 10 days);
        assertEq(openStart, 0);
        assertEq(openExpiry, 0);
        assertTrue(!deposited);
    }

    /*//////////////////////////////////////////////////////////////
                              withdraw
    //////////////////////////////////////////////////////////////*/

    // TODO

    /*//////////////////////////////////////////////////////////////
                              claim
    //////////////////////////////////////////////////////////////*/

    // TODO

    /*//////////////////////////////////////////////////////////////
                          transferTresury
    //////////////////////////////////////////////////////////////*/

    // TODO
}
