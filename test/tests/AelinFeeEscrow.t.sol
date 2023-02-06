// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {AelinNftGating} from "contracts/libraries/AelinNftGating.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MerkleTree} from "contracts/libraries/MerkleTree.sol";

contract AelinFeeEscrowTest is Test, AelinTestUtils {
    using SafeERC20 for IERC20;

    AelinUpFrontDeal public testUpFrontDeal;
    AelinUpFrontDealFactory public upFrontDealFactory;
    AelinFeeEscrow public testEscrow;

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;

    address upfrontDeal;
    address escrowAddress;

    event SetTreasury(address indexed treasury);
    event InitializeEscrow(
        address indexed dealAddress,
        address indexed treasury,
        uint256 vestingExpiry,
        address indexed escrowedToken
    );
    event DelayEscrow(uint256 vestingExpiry);

    function setUp() public {
        testUpFrontDeal = new AelinUpFrontDeal();
        testEscrow = new AelinFeeEscrow();
        upFrontDealFactory = new AelinUpFrontDealFactory(address(testUpFrontDeal), address(testEscrow), aelinTreasury);
        purchaseToken = new MockERC20("MockPurchase", "MP");

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
            holder: dealHolderAddress,
            sponsor: dealCreatorAddress,
            sponsorFee: 1 * 10 ** 18,
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
        vm.startPrank(dealHolderAddress);
        deal(address(underlyingDealToken), dealHolderAddress, type(uint256).max);
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
    function test_initialize_RevertIf_ExecutesMoreThanOnce() public {
        vm.expectRevert("can only initialize once");
        AelinFeeEscrow(escrowAddress).initialize(aelinTreasury, address(underlyingDealToken));
    }

    // Pass scenario
    function test_Initialize() public {
        assertEq(AelinFeeEscrow(escrowAddress).treasury(), aelinTreasury, "aelinTreasuryAddress");
        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), block.timestamp + 180 days, "vestingExpiry");
        assertEq(AelinFeeEscrow(escrowAddress).escrowedToken(), address(underlyingDealToken), "escrowedToken");
    }

    function test_InitializeEvent() public {
        vm.expectEmit(true, true, true, true, address(testEscrow));
        emit InitializeEscrow(address(this), aelinTreasury, block.timestamp + 180 days, address(underlyingDealToken));
        AelinFeeEscrow(testEscrow).initialize(aelinTreasury, address(underlyingDealToken));
    }

    /*//////////////////////////////////////////////////////////////
                            setTreasury()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testFuzz_setTreasury_RevertIf_SenderIsNotTreasury(address _wrongAddress, address _newAddress) public {
        vm.assume(_wrongAddress != aelinTreasury);
        vm.startPrank(_wrongAddress);
        vm.expectRevert("must be treasury");
        AelinFeeEscrow(escrowAddress).setTreasury(_newAddress);
        vm.stopPrank();
    }

    function test_setTreasury_RevertIf_SetsTreasuryWithZeroAddress() public {
        vm.startPrank(aelinTreasury);
        vm.expectRevert("cant pass null treasury address");
        AelinFeeEscrow(escrowAddress).setTreasury(address(0));
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_setTresury(address _newAddress) public {
        vm.assume(_newAddress != address(0));

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_newAddress);
        assertEq(AelinFeeEscrow(escrowAddress).futureTreasury(), _newAddress, "futureTreasuryAddress");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            acceptTreasury()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testFuzz_acceptTreasury_RevertIf_SenderIsNotFutureTreasury(
        address _futureTreasury,
        address _wrongAddress
    ) public {
        vm.assume(_futureTreasury != address(0));
        vm.assume(_wrongAddress != _futureTreasury);

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_futureTreasury);
        vm.stopPrank();

        vm.startPrank(_wrongAddress);
        vm.expectRevert("must be future treasury");
        AelinFeeEscrow(escrowAddress).acceptTreasury();
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_acceptTreasury(address _futureTreasury) public {
        vm.assume(_futureTreasury != address(0));

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).setTreasury(_futureTreasury);
        vm.stopPrank();

        vm.startPrank(_futureTreasury);
        vm.expectEmit(true, true, true, true, escrowAddress);
        emit SetTreasury(_futureTreasury);
        AelinFeeEscrow(escrowAddress).acceptTreasury();
        assertEq(AelinFeeEscrow(escrowAddress).treasury(), _futureTreasury, "futureTreasuryAddress");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            delayEscrow()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testFuzz_delayEscrow_RevertIf_SenderIsNotTreasury(address _wrongAddress) public {
        vm.assume(_wrongAddress != aelinTreasury);

        vm.startPrank(_wrongAddress);
        vm.expectRevert("must be treasury");
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();
    }

    function testFuzz_delayEscrow_RevertIf_CalledTooEarly(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();
        (bool success, ) = SafeMath.tryAdd(_delay, 90 days);
        vm.assume(success);
        vm.assume(vestingExpiry >= _delay + 90 days);

        vm.startPrank(aelinTreasury);
        vm.warp(_delay);
        vm.expectRevert("must not shorten vesting period");
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_delayEscrow(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();
        (bool success, ) = SafeMath.tryAdd(_delay, 90 days);
        vm.assume(success);
        vm.assume(vestingExpiry < _delay + 90 days);

        vm.startPrank(aelinTreasury);
        vm.warp(_delay);
        vm.expectEmit(true, true, true, true, escrowAddress);
        emit DelayEscrow(_delay + 90 days);
        AelinFeeEscrow(escrowAddress).delayEscrow();
        vm.stopPrank();

        assertEq(AelinFeeEscrow(escrowAddress).vestingExpiry(), _delay + 90 days, "vestingExpiry");
    }

    /*//////////////////////////////////////////////////////////////
                            withdrawToken()
    //////////////////////////////////////////////////////////////*/

    // Revert scenarios
    function testFuzz_withdrawToken_RevertIf_SenderIsNotTreasury(address _wrongAddress) public {
        vm.assume(_wrongAddress != aelinTreasury);

        vm.startPrank(_wrongAddress);
        vm.expectRevert("must be treasury");
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();
    }

    function testFuzz_withdrawToken_RevertIf_BeforeVestingExpiry(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();
        vm.assume(_delay <= vestingExpiry);
        vm.warp(_delay);

        vm.startPrank(aelinTreasury);
        vm.expectRevert("cannot access funds yet");
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();
    }

    // Pass scenario
    function testFuzz_withdrawToken(uint256 _delay) public {
        uint256 vestingExpiry = AelinFeeEscrow(escrowAddress).vestingExpiry();

        uint256 feeAmount = (AelinUpFrontDeal(upfrontDeal).totalPoolShares() * AELIN_FEE) / BASE;
        assertEq(feeAmount, IERC20(underlyingDealToken).balanceOf(address(escrowAddress)));

        vm.assume(_delay > vestingExpiry);
        vm.warp(_delay);

        vm.startPrank(aelinTreasury);
        AelinFeeEscrow(escrowAddress).withdrawToken();
        vm.stopPrank();

        assertEq(IERC20(underlyingDealToken).balanceOf(address(escrowAddress)), 0);
        assertEq(IERC20(underlyingDealToken).balanceOf(aelinTreasury), feeAmount, "aelinFeeAmt");
    }
}
