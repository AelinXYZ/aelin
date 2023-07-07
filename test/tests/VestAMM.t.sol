// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/AelinLibraryList.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/libraries/MerkleTree.sol";
import "contracts/VestAMM/libraries/AmmIntegration/SushiVestAMM.sol";

import {VestAMMLibrary} from "./utils/VestAMMLibrary.sol";
import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMDealFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import {VestAMM} from "contracts/VestAMM/VestAMM.sol";

contract VestAMMTest is AelinVestAMMTest {
    function testDepositSingle() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary sushiLibrary = new VestAMMLibrary(sushiLibraryAddress);
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibraryAddress);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibraryAddress, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        IVestAMM.DepositToken[] memory depositSingle = new IVestAMM.DepositToken[](1);
        //depositSingle[0] = IVestAMM.DepositToken(0, 0, aaveToken, 0.5 ether);

        IERC20(aaveToken).approve(address(vestAMM), 0.5 ether);

        vm.expectEmit(true, true, true, true);
        emit SingleRewardDeposited(user, 0, 0, aaveToken, 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        // Assert
        assertTrue(IERC20(aaveToken).balanceOf(address(vestAMM)) == 0.5 ether);
        //assertTrue(vestAMM.holderDeposits(user, 0, 0) == 0.5 ether);
        assertFalse(vestAMM.depositComplete()); // Need to deposit Base
    }

    function testDepositBase() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary sushiLibrary = new VestAMMLibrary(sushiLibraryAddress);
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibraryAddress);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibraryAddress, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        IERC20(aelinToken).approve(address(vestAMM), 1 ether);
        vestAMM.depositBase();

        // Assert
        assertTrue(IERC20(aelinToken).balanceOf(address(vestAMM)) == 1 ether);
        assertTrue(vestAMM.amountBaseDeposited() == 1 ether);
        assertFalse(vestAMM.depositComplete()); // Need to deposit single
    }

    function testDepositCompleted() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);
        deal(aelinToken, user, 1 ether);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary sushiLibrary = new VestAMMLibrary(sushiLibraryAddress);
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibraryAddress);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibraryAddress, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        // Deposit Base
        IERC20(aelinToken).approve(address(vestAMM), 1 ether);
        vestAMM.depositBase();

        // Deposit Single
        IVestAMM.DepositToken[] memory depositSingle = new IVestAMM.DepositToken[](1);
        //depositSingle[0] = IVestAMM.DepositToken(0, 0, aaveToken, 0.5 ether);

        IERC20(aaveToken).approve(address(vestAMM), 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        // Assert
        assertTrue(vestAMM.depositComplete());
        assertTrue(vestAMM.depositExpiry() == block.timestamp + info.depositWindow);
        assertTrue(vestAMM.lpFundingExpiry() == block.timestamp + info.depositWindow + info.lpFundingWindow);
    }

    function testAddSingle() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);
        deal(usdcToken, user, 1 ether);
        deal(aelinToken, user, 1 ether);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary sushiLibrary = new VestAMMLibrary(sushiLibraryAddress);
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibraryAddress);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibraryAddress, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        // Deposit Base
        IERC20(aelinToken).approve(address(vestAMM), 1 ether);
        vestAMM.depositBase();

        //Add single
        IVestAMM.SingleVestingSchedule[] memory single = new IVestAMM.SingleVestingSchedule[](1);
        /*
        single[0] = IVestAMM.SingleVestingSchedule(
            usdcToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            1 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );
        */
        uint256[] memory lpVestingIndexList = new uint256[](1);
        lpVestingIndexList[0] = 0;
        //vestAMM.addSingle(lpVestingIndexList, single);

        IVestAMM.DepositToken[] memory depositSingle = new IVestAMM.DepositToken[](1);
        //depositSingle[0] = IVestAMM.DepositToken(0, 0, aaveToken, 0.5 ether);

        IERC20(aaveToken).approve(address(vestAMM), 0.5 ether);
        vm.expectEmit(true, true, true, true);
        emit SingleRewardDeposited(user, 0, 0, aaveToken, 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        assertFalse(vestAMM.depositComplete()); // Need to the singleReward token just added

        //depositSingle[0] = IVestAMM.DepositToken(0, 1, usdcToken, 0.5 ether);
        IERC20(usdcToken).approve(address(vestAMM), 0.5 ether);
        vm.expectEmit(true, true, true, true);
        emit SingleRewardDeposited(user, 0, 1, usdcToken, 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        assertFalse(vestAMM.depositComplete()); // MMust totalRewardTokens (just added 0.5)

        //depositSingle[0] = IVestAMM.DepositToken(0, 1, usdcToken, 0.5 ether);
        IERC20(usdcToken).approve(address(vestAMM), 0.5 ether);
        vm.expectEmit(true, true, true, true);
        emit SingleRewardDeposited(user, 0, 1, usdcToken, 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        assertTrue(vestAMM.depositComplete()); // Added all
    }

    function testCreateInitialLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);
        deal(aelinToken, user, 1 ether);
        deal(daiToken, investor, 1 ether);

        address sushiLibrary = deployCode("SushiVestAMM.sol");
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibrary);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibrary, 0);
        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        // Deposit Base
        IERC20(aelinToken).approve(address(vestAMM), 1 ether);
        vestAMM.depositBase();

        // Deposit single
        IVestAMM.DepositToken[] memory depositSingle = new IVestAMM.DepositToken[](1);
        //depositSingle[0] = IVestAMM.DepositToken(0, 0, aaveToken, 0.5 ether);
        IERC20(aaveToken).approve(address(vestAMM), 0.5 ether);
        //vestAMM.depositSingle(depositSingle);

        vm.stopPrank();

        //Acept deal
        vm.startPrank(investor);
        IERC20(daiToken).approve(address(vestAMM), 1 ether);

        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        MerkleTree.UpFrontMerkleData memory merkleData;
        uint256 investmentTokenAmount = 1 ether;
        uint8 vestingScheduleIndex = 0;

        //vestAMM.acceptDeal(nftPurchaseList, merkleData, investmentTokenAmount, vestingScheduleIndex);
        vm.stopPrank();

        vm.warp(block.timestamp + info.depositWindow + 1);

        // Create initial liquidity
        vm.startPrank(user, user);
        vestAMM.createInitialLiquidity();

        // Assert
        // assertDeposit Data
        // assert
    }

    function testRemoveSingle() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);
        deal(aelinToken, user, 1 ether);
        deal(daiToken, investor, 1 ether);

        address sushiLibrary = deployCode("SushiVestAMM.sol");
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibrary);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibrary, 0);

        IVestAMM.SingleVestingSchedule[] memory single2 = new IVestAMM.SingleVestingSchedule[](2);
        /*
        single2[0] = IVestAMM.SingleVestingSchedule(
            aaveToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            0.1 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );

        single2[1] = IVestAMM.SingleVestingSchedule(
            daiToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            0.1 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );
        */

        //info.lpVestingSchedules[0].singleVestingSchedules = new IVestAMM.SingleVestingSchedule[](2);
        //info.lpVestingSchedules[0].singleVestingSchedules = single2;

        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        // Deposit Base
        IERC20(aelinToken).approve(address(vestAMM), 1 ether);
        vestAMM.depositBase();

        assertFalse(vestAMM.depositComplete());

        // Remove Single
        //IVestAMM.RemoveSingle memory removeSingleData = IVestAMM.RemoveSingle(0, 1);
        //vestAMM.removeSingle(removeSingleData);

        // Deposit single
        IVestAMM.DepositToken[] memory depositSingle = new IVestAMM.DepositToken[](1);
        //depositSingle[0] = IVestAMM.DepositToken(0, 0, aaveToken, 0.5 ether);
        IERC20(aaveToken).approve(address(vestAMM), 0.5 ether);
        //vestAMM.depositSingle(depositSingle);
        vm.stopPrank();

        assertTrue(vestAMM.depositComplete());
    }

    function testSingleRewardsToDeposit() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aaveToken, user, 1 ether);
        deal(aelinToken, user, 1 ether);
        deal(daiToken, investor, 1 ether);

        address sushiLibrary = deployCode("SushiVestAMM.sol");
        AelinLibraryList libraryList = new AelinLibraryList(user);
        libraryList.addLibrary(sushiLibrary);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(address(0), daiToken, aelinToken, sushiLibrary, 0);

        IVestAMM.SingleVestingSchedule[] memory single2 = new IVestAMM.SingleVestingSchedule[](2);
        /*
        single2[0] = IVestAMM.SingleVestingSchedule(
            aaveToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            0.1 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );

        single2[1] = IVestAMM.SingleVestingSchedule(
            daiToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            0.5 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );
        */

        //info.lpVestingSchedules[0].singleVestingSchedules = new IVestAMM.SingleVestingSchedule[](2);
        //info.lpVestingSchedules[0].singleVestingSchedules = single2;

        IVestAMM.DealAccess memory dealAccess = getDealAccess();

        AelinFeeModule feeModule = new AelinFeeModule();
        VestAMM vestAMM = new VestAMM();

        //vestAMM.initialize(info, dealAccess, address(feeModule));

        //IVestAMM.DepositToken[] memory depositTokens = vestAMM.singleRewardsToDeposit(user);

        // Assert SingleReward 1
        /*
        assertTrue(depositTokens[0].lpScheduleIndex == 0);
        assertTrue(depositTokens[0].singleRewardIndex == 0);
        assertTrue(depositTokens[0].token == aaveToken);
        assertTrue(depositTokens[0].amount == 0.1 ether);

        // Assert SingleReward 2
        assertTrue(depositTokens[1].lpScheduleIndex == 0);
        assertTrue(depositTokens[1].singleRewardIndex == 1);
        assertTrue(depositTokens[1].token == daiToken);
        assertTrue(depositTokens[1].amount == 0.5 ether);
        */
    }
}
