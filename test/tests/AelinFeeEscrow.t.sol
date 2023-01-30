// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "../../contracts/libraries/AelinNftGating.sol";
import "../../contracts/libraries/AelinAllowList.sol";
import "../../contracts/libraries/MerkleTree.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinFeeEscrowTest is Test {
    using SafeERC20 for IERC20;

    uint256 constant MAX_SPONSOR_FEE = 15 * 10**18;
    uint256 constant AELIN_FEE = 2 * 10**18;

    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);

    AelinUpFrontDeal public testUpFrontDeal;
    AelinUpFrontDealFactory public upFrontDealFactory;
    AelinFeeEscrow public testEscrow;
    MockERC20 public purchaseToken;
    MockERC20 public underlyingDealToken;

    MerkleTree.UpFrontMerkleData public merkleDataEmpty;
    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);

    address upfrontDeal;
    address escrowAddress;

    function setUp() public {
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);
        purchaseToken = new MockERC20("MockPurchase", "MP");
        underlyingDealToken = new MockERC20("MockDeal", "MD");

        AelinAllowList.InitData memory allowListInitEmpty;
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;

        vm.startPrank(dealCreatorAddress);
        deal(address(this), type(uint256).max);
        deal(address(underlyingDealToken), address(dealCreatorAddress), type(uint256).max);
        underlyingDealToken.approve(address(upFrontDealFactory), type(uint256).max);

        // Deal initialization
        IAelinUpFrontDeal.UpFrontDealData memory dealData;
        dealData = IAelinUpFrontDeal.UpFrontDealData({
            name: "DEAL",
            symbol: "DEAL",
            purchaseToken: address(purchaseToken),
            underlyingDealToken: address(underlyingDealToken),
            holder: address(0xDEAD),
            sponsor: address(0xBEEF),
            sponsorFee: 1 * 10**18,
            ipfsHash: "",
            merkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        IAelinUpFrontDeal.UpFrontDealConfig memory dealConfig;
        dealConfig = IAelinUpFrontDeal.UpFrontDealConfig({
            underlyingDealTokenTotal: 1e35,
            purchaseTokenPerDealToken: 3e20,
            purchaseRaiseMinimum: 0,
            purchaseDuration: 10 days,
            vestingPeriod: 365 days,
            vestingCliffPeriod: 60 days,
            allowDeallocation: true
        });

        upfrontDeal = upFrontDealFactory.createUpFrontDeal(
            dealData,
            dealConfig,
            nftCollectionRulesEmpty,
            allowListInitEmpty
        );
        vm.stopPrank();

        // Fund the deal
        vm.startPrank(address(0xDEAD));
        deal(address(underlyingDealToken), address(0xDEAD), type(uint256).max);
        underlyingDealToken.approve(address(upfrontDeal), type(uint256).max);
        AelinUpFrontDeal(upfrontDeal).depositUnderlyingTokens(1e35);
        vm.stopPrank();

        // User1 accepts deal
        vm.startPrank(user1);
        deal(address(purchaseToken), user1, 3e18);
        purchaseToken.approve(address(upfrontDeal), 3e18);
        AelinUpFrontDeal(upfrontDeal).acceptDeal(nftPurchaseList, merkleDataEmpty, 3e18);
        vm.stopPrank();

        // Holder claim
        vm.startPrank(dealHolderAddress);
        uint256 purchaseExpiry = AelinUpFrontDeal(upfrontDeal).purchaseExpiry();
        vm.warp(purchaseExpiry + 1000);
        AelinUpFrontDeal(upfrontDeal).holderClaim();
        vm.stopPrank();

        escrowAddress = address(AelinUpFrontDeal(upfrontDeal).aelinFeeEscrow());
    }

    /*//////////////////////////////////////////////////////////////
                            initialize()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testRevertInitializeInitMoreThanOnce() public {
        vm.expectRevert("can only initialize once");
        AelinFeeEscrow(escrowAddress).initialize(aelinTreasury, address(underlyingDealToken));
    }

    // Pass scenario
    function testInitialize() public {
        assertEq(AelinFeeEscrow(escrowAddress).treasury(), aelinTreasury);
        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp + 180 days);
        assertEq(AelinFeeEscrow(escrowAddress).escrowedToken(), address(underlyingDealToken));
    }

    /*//////////////////////////////////////////////////////////////
                            setTresury()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testRevertSetTresuryOnlyTreasury(address _wrongAddress, address _newAddress) public {
        vm.startPrank(_wrongAddress);
        vm.expectRevert("only treasury can access");
        AelinFeeEscrow(escrowAddress).setTreasury(_newAddress);
        vm.stopPrank();
    }

    function testRevertSetTresuryNoZeroAddress() public {
        vm.startPrank(aelinTreasury);
        vm.expectRevert();
        AelinFeeEscrow(escrowAddress).setTreasury(address(0));
        vm.stopPrank();
    }

    // Pass scenario
    function testSetTresury(address _newAddress) public {
        vm.assume(_newAddress != address(0));

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_newAddress);
        assertEq(_newAddress, AelinFeeEscrow(escrowAddress).futureTreasury());
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            acceptTreasury()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testRevertAcceptTreasuryOnlyFutureTreasury(address _futureTreasury, address _wrongAddress) public {
        vm.assume(_futureTreasury != address(0));
        vm.assume(_wrongAddress != _futureTreasury);

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_futureTreasury);
        vm.stopPrank();

        vm.startPrank(_wrongAddress);
        vm.expectRevert("only future treasury can access");
        AelinFeeEscrow(escrowAddress).acceptTreasury();
        vm.stopPrank();
    }

    // Pass scenario
    function testAcceptTreasury(address _futureTreasury) public {
        vm.assume(_futureTreasury != address(0));

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_futureTreasury);
        vm.stopPrank();

        vm.startPrank(_futureTreasury);
        AelinFeeEscrow(escrowAddress).acceptTreasury();
        assertEq(_futureTreasury, AelinFeeEscrow(escrowAddress).treasury());
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            delayEscrow()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testRevertDelayEscrowOnlyTreasury(address _wrongAddress) public {
        vm.assume(_wrongAddress != aelinTreasury);

        vm.startPrank(_wrongAddress);
        vm.expectRevert("only treasury can access");
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();
    }

    function testRevertDelayEscrowDelayTooLong(uint256 _delay) public {
        vm.assume(_delay < 90 days);

        vm.startPrank(aelinTreasury);
        vm.warp(_delay);
        vm.expectRevert("can only extend by 90 days");
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();
    }

    // Pass scenario
    function testDealyEscrow(uint256 _delay) public {
        vm.assume(_delay > 100 days);
        vm.assume(_delay < 365 days);

        vm.startPrank(aelinTreasury);
        vm.warp(_delay);
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();

        assertEq(_delay + 90 days, AelinFeeEscrow(escrowAddress).vestingExpiry());
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawToken()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testRevertWithdrawTokenOnlyTreasury(address _wrongAddress) public {
        vm.assume(_wrongAddress != aelinTreasury);

        vm.startPrank(_wrongAddress);
        vm.expectRevert("only treasury can access");
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();
    }

    function testRevertWithdrawTokenCannotAccessFunds(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();
        vm.assume(_delay < vestingExpiry);
        vm.warp(_delay);

        vm.startPrank(aelinTreasury);
        vm.expectRevert("cannot access funds yet");
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();
    }

    // Pass scenario
    function testWithdrawToken(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();
        uint256 purchaseTokenPerDealToken;
        (, purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(upfrontDeal).dealConfig();
        uint256 aelinFeeAmt = (3e18 * AELIN_FEE) / (purchaseTokenPerDealToken * 100);

        vm.assume(_delay > vestingExpiry);
        vm.warp(_delay);

        vm.startPrank(aelinTreasury);
        vm.warp(_delay);
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();

        assertEq(aelinFeeAmt, IERC20(underlyingDealToken).balanceOf(aelinTreasury));
    }
}
