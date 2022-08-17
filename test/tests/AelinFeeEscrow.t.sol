// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinFeeEscrowTest is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public poolAddress;
    address public dealAddress;
    address public escrowAddress;

    AelinPool public testPool;
    AelinDeal public testDeal;
    AelinPoolFactory public poolFactory;
    AelinFeeEscrow public testEscrow;

    MockERC20 public dealToken;
    MockERC20 public purchaseToken;

    event InitializeEscrow(
        address indexed dealAddress,
        address indexed treasury,
        uint256 vestingExpiry,
        address indexed escrowedToken
    );
    event DelayEscrow(uint256 vestingExpiry);

    function setUp() public {
        testPool = new AelinPool();
        testDeal = new AelinDeal();
        testEscrow = new AelinFeeEscrow();
        poolFactory = new AelinPoolFactory(address(testPool), address(testDeal), aelinTreasury, address(testEscrow));
        dealToken = new MockERC20("MockDeal", "MD");
        purchaseToken = new MockERC20("MockPool", "MP");

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;
        IAelinPool.NftCollectionRules[] memory nftCollectionRules;

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
            nftCollectionRules: nftCollectionRules
        });

        poolAddress = poolFactory.createPool(poolData);

        deal(address(purchaseToken), address(this), 1e75);
        deal(address(dealToken), address(this), 1e75);

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
        vm.warp(block.timestamp + 10 days);
        AelinDeal(dealAddress).depositUnderlying(1e35);
        escrowAddress = address(AelinDeal(dealAddress).aelinFeeEscrow());
    }

    function testInitialize() public {
        assertTrue(AelinDeal(dealAddress).depositComplete());
        assertEq(AelinFeeEscrow(escrowAddress).treasury(), address(aelinTreasury));
        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp);
        assertEq(AelinFeeEscrow(escrowAddress).escrowedToken(), address(dealToken));
    }

    function testInitializeEvent() public {
        vm.expectEmit(true, true, true, true, address(testEscrow));
        emit InitializeEscrow(address(this), aelinTreasury, block.timestamp, address(dealToken));
        AelinFeeEscrow(testEscrow).initialize(aelinTreasury, address(dealToken));
    }

    function testSetTreasury(address testAddress) public {
        vm.assume(testAddress != address(0));
        vm.prank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).setTreasury(testAddress);

        assertEq(AelinFeeEscrow(escrowAddress).futureTreasury(), testAddress);
    }

    function testFailSetTreasury(address testAddress) public {
        vm.assume(testAddress != address(aelinTreasury));
        vm.prank(address(testAddress));
        AelinFeeEscrow(escrowAddress).setTreasury(testAddress);
    }

    function testAcceptTreasury(address testAddress) public {
        vm.assume(testAddress != address(0));
        vm.prank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).setTreasury(testAddress);

        vm.prank(address(testAddress));
        AelinFeeEscrow(escrowAddress).acceptTreasury();

        assertEq(AelinFeeEscrow(escrowAddress).treasury(), address(testAddress));
    }

    function testFailAcceptTreasury(address testAddress1, address testAddress2) public {
        vm.assume(testAddress1 != testAddress2);
        vm.prank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).setTreasury(testAddress1);

        vm.prank(address(testAddress2));
        AelinFeeEscrow(escrowAddress).acceptTreasury();
    }

    function testDelayEscrow() public {
        vm.prank(address(aelinTreasury));
        vm.expectEmit(false, false, false, true, address(escrowAddress));
        emit DelayEscrow(block.timestamp + 90 days);
        AelinFeeEscrow(escrowAddress).delayEscrow();

        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp + 90 days);
    }

    function testFailDelayEscrow() public {
        vm.prank(address(aelinTreasury));
        vm.expectEmit(false, false, false, true, address(escrowAddress));
        emit DelayEscrow(block.timestamp + 90 days);
        AelinFeeEscrow(escrowAddress).delayEscrow();
        AelinFeeEscrow(escrowAddress).delayEscrow();
    }

    function testFailDelayEscrowDiffAddress(address testAddress) public {
        vm.assume(address(aelinTreasury) != testAddress);
        vm.prank(testAddress);
        AelinFeeEscrow(escrowAddress).delayEscrow();
    }

    function testWithdrawToken() public {
        AelinPool(poolAddress).acceptMaxDealTokens();

        uint256 escrowBalance = IERC20(dealToken).balanceOf(address(escrowAddress));
        vm.warp(block.timestamp + 181 days);
        vm.prank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).withdrawToken();

        assertEq(IERC20(dealToken).balanceOf(address(escrowAddress)), 0);
        assertEq(IERC20(dealToken).balanceOf(aelinTreasury), escrowBalance);
    }

    function testFailWithdrawToken(uint256 amount) public {
        vm.assume(amount < 1e75);
        AelinFeeEscrow(escrowAddress).withdrawToken();
    }
}
