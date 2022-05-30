// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinUpFrontDealTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public upFrontDealAddress;

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
        deal(address(purchaseToken), address(0xBEEF), 1e75);

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
        IERC20(dealToken).approve(address(0xdd36aa107BcA36Ba4606767D873B13B4770F3b12), 1e35);
        upFrontDealAddress = AelinUpFrontDealFactory(upFrontDealFactory).createUpFrontDeal(poolData, dealData, 1e35);
    }

    function testPurchaseAndAccept(uint256 amount) public {
        vm.assume(amount <= 1e35);
        IAelinPool.NftPurchaseList[] memory nftPurchaseList;

        IERC20(purchaseToken).approve(upFrontDealAddress, amount);
        AelinUpFrontDeal(upFrontDealAddress).purchasePoolAndAccept(nftPurchaseList, amount);

        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - amount);
        assertEq(IERC20(purchaseToken).balanceOf(upFrontDealAddress), amount);
        assertEq(IERC20(dealToken).balanceOf(upFrontDealAddress), 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - 1e35);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).totalAmountAccepted(), amount);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).currentDealTokenTotal(), 1e35);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).amountAccepted(address(this)), amount);
    }

    function testPurchaseAndAcceptWithDiffWallet(uint256 amount) public {
        vm.assume(amount <= 1e35);
        IAelinPool.NftPurchaseList[] memory nftPurchaseList;

        vm.startPrank(address(0xBEEF));
        IERC20(purchaseToken).approve(upFrontDealAddress, amount);
        AelinUpFrontDeal(upFrontDealAddress).purchasePoolAndAccept(nftPurchaseList, amount);
        vm.stopPrank();

        assertEq(IERC20(purchaseToken).balanceOf(upFrontDealAddress), amount);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75);
        assertEq(IERC20(purchaseToken).balanceOf(address(0xBEEF)), 1e75 - amount);
        assertEq(IERC20(dealToken).balanceOf(upFrontDealAddress), 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(0xBEEF)), 0);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).totalAmountAccepted(), amount);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).currentDealTokenTotal(), 1e35);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).amountAccepted(address(this)), 0);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).amountAccepted(address(0xBEEF)), amount);
    }

    function testPurchaseAndAcceptWithMultipleWallets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= 1e35 / 2);
        vm.assume(amount2 <= 1e35 / 2);
        vm.assume(amount1 + amount2 <= 1e35);
        IAelinPool.NftPurchaseList[] memory nftPurchaseList;

        IERC20(purchaseToken).approve(upFrontDealAddress, amount1);
        AelinUpFrontDeal(upFrontDealAddress).purchasePoolAndAccept(nftPurchaseList, amount1);

        vm.startPrank(address(0xBEEF));
        IERC20(purchaseToken).approve(upFrontDealAddress, amount2);
        AelinUpFrontDeal(upFrontDealAddress).purchasePoolAndAccept(nftPurchaseList, amount2);
        vm.stopPrank();

        assertEq(IERC20(purchaseToken).balanceOf(upFrontDealAddress), amount1 + amount2);
        assertEq(IERC20(purchaseToken).balanceOf(address(this)), 1e75 - amount1);
        assertEq(IERC20(purchaseToken).balanceOf(address(0xBEEF)), 1e75 - amount2);
        assertEq(IERC20(dealToken).balanceOf(upFrontDealAddress), 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(this)), 1e75 - 1e35);
        assertEq(IERC20(dealToken).balanceOf(address(0xBEEF)), 0);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).totalAmountAccepted(), amount1 + amount2);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).currentDealTokenTotal(), 1e35);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).amountAccepted(address(this)), amount1);
        assertEq(AelinUpFrontDeal(upFrontDealAddress).amountAccepted(address(0xBEEF)), amount2);
    }
}
