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
        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp + 180 days);
        assertEq(AelinFeeEscrow(escrowAddress).escrowedToken(), address(dealToken));
    }

    function testSetTreasury(address testAddress) public {
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

    function testDelayEscrow(uint256 timestamp) public {
        // 90 days + block.timestamp which is 30 days 
        vm.assume(timestamp > 120 days);
        vm.assume(timestamp < 1e75);
        vm.prank(address(aelinTreasury));
        vm.warp(timestamp);
        AelinFeeEscrow(escrowAddress).delayEscrow();

        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp + 90 days);
    }

    function testFailDelayEscrow(uint256 timestamp) public {
        vm.assume(timestamp < 120 days);
        vm.warp(timestamp);
        vm.prank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).delayEscrow();
    }

    function testFailDelayEscrowDiffAddress(uint256 timestamp, address testAddress) public {
        vm.assume(timestamp > 120 days);
        vm.assume(timestamp < type(uint256).max);
        vm.warp(timestamp);
        vm.prank(testAddress);
        AelinFeeEscrow(escrowAddress).delayEscrow();
    }

    function testTransferToken(address to, uint256 amount) public {
        vm.assume(amount < 1e75);
        vm.assume(to != address(0));
        vm.startPrank(address(aelinTreasury));
        address[] memory transferToken = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            transferToken[i] = address(new MockERC20("TransferToken", "TT"));
            deal(transferToken[i], address(escrowAddress), amount);
            AelinFeeEscrow(escrowAddress).transferToken(address(transferToken[i]), to, amount);

            assertEq(IERC20(transferToken[i]).balanceOf(address(escrowAddress)), 0);
            assertEq(IERC20(transferToken[i]).balanceOf(to), amount);
        }
        vm.stopPrank();
    }

    function testTransferEscrowedToken(address to, uint256 amount) public {
        vm.assume(amount < 1e35);
        vm.assume(to != address(0));
        vm.warp(block.timestamp + 181 days);
        vm.startPrank(address(aelinTreasury));
        deal(address(dealToken), address(escrowAddress), amount);
        AelinFeeEscrow(escrowAddress).transferToken(address(dealToken), to, amount);
        vm.stopPrank();

        assertEq(IERC20(dealToken).balanceOf(address(escrowAddress)), 0);
        assertEq(IERC20(dealToken).balanceOf(to), amount);
    }

    function testTransferAfterDealAccepted(address to, uint256 amount) public {
        // 1e35 * 2%
        vm.assume(amount < 2e33);
        vm.assume(to != address(0));

        AelinPool(poolAddress).acceptMaxDealTokens();

        uint256 escrowBalance = IERC20(dealToken).balanceOf(address(escrowAddress));

        vm.warp(block.timestamp + 181 days);
        vm.startPrank(address(aelinTreasury));
        AelinFeeEscrow(escrowAddress).transferToken(address(dealToken), to, amount);
        vm.stopPrank();

        assertEq(IERC20(dealToken).balanceOf(address(escrowAddress)), escrowBalance - amount);
        assertEq(IERC20(dealToken).balanceOf(to), amount);
    }
}