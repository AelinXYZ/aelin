// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {BalancerVestAMM} from "contracts/VestAMM/libraries/AmmIntegration/BalancerVestAMM.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

import "contracts/VestAMM/interfaces/balancer/IBalancerPool.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DerivedBalancerVestAMM {
    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) public returns (address) {
        return BalancerVestAMM.deployPool(_newPool);
    }

    function addInitialLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return BalancerVestAMM.addInitialLiquidity(_addLiquidityData);
    }

    function addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return BalancerVestAMM.addLiquidity(_addLiquidityData);
    }

    function removeLiquidity(IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData) external {
        BalancerVestAMM.removeLiquidity(_removeLiquidityData);
    }

    function checkPoolExists(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (bool) {
        return BalancerVestAMM.checkPoolExists(_vammInfo);
    }
}

contract BalancerLibraryTest is Test {
    uint256 mainnetFork;
    IERC20 Aelin = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
    IERC20 Dai = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    address user = address(0xA6B49397ce21bb62200e914F41BF371E5940Bb41);

    struct BalancerPoolData {
        string name;
        string symbol;
        address[] tokens;
        uint256[] normalizedWeights;
        IRateProvider[] rateProviders;
        uint256 swapFeePercentage;
        DerivedBalancerVestAMM balancerLib;
        address pool;
    }

    // Alchemy url + key in .env
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function getBalancerTestData() public returns (BalancerPoolData memory) {
        address[] memory tokens = new address[](2);
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        uint256[] memory normalizedWeights = new uint256[](2);

        tokens[0] = address(Dai);
        tokens[1] = address(Aelin);
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));
        normalizedWeights[0] = 500000000000000000;
        normalizedWeights[1] = 500000000000000000;

        IVestAMMLibrary.CreateNewPool memory newPoolData = IVestAMMLibrary.CreateNewPool(
            "aelindai",
            "AELIN-DAI",
            tokens,
            normalizedWeights,
            rateProviders,
            2500000000000000, // 2,5%
            address(0), // OWNER: Do we need this?,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        );

        DerivedBalancerVestAMM balancerLib = new DerivedBalancerVestAMM();

        // First we need to approve the VestAMM(or the library for this test case) to use user's tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(balancerLib), type(uint256).max);
        }

        address pool = balancerLib.deployPool(newPoolData);

        BalancerPoolData memory data;

        data.balancerLib = balancerLib;
        data.name = "aelindai";
        data.symbol = "AELIN-DAI";
        data.tokens = tokens;
        data.normalizedWeights = normalizedWeights;
        data.rateProviders = rateProviders;
        data.swapFeePercentage = 2500000000000000;
        data.pool = pool;

        return data;
    }

    function getVestAMMInfo(bytes32 poolId) public returns (IVestAMM.VAmmInfo memory) {
        IVestAMM.AmmData memory ammData = IVestAMM.AmmData(address(0), address(0), address(0));

        IVestAMM.SingleVestingSchedule[] memory single = new IVestAMM.SingleVestingSchedule[](1);
        single[0] = IVestAMM.SingleVestingSchedule(
            address(0), // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            address(0), //singleHolder
            0, //totalSingleTokens
            0, //claimed;
            true //finalizedDeposit;
        );

        IVestAMM.LPVestingSchedule[] memory lpSchedules = new IVestAMM.LPVestingSchedule[](1);
        lpSchedules[0] = IVestAMM.LPVestingSchedule(
            single, //singleVestingSchedules[]
            0, //vestingPeriod;
            0, //vestingCliffPeriod;
            0, //totalBaseTokens;
            0, // totalLPTokens;
            0, // claimed;
            true, //finalizedDeposit;
            0 //investorLPShare; // 0 - 100
        );

        IVestAMM.VAmmInfo memory info = IVestAMM.VAmmInfo(
            ammData,
            false, //bool hasLaunchPhase;
            0, //investmentPerBase;
            0, // depositWindow;
            0, //lpFundingWindow;
            address(0), //mainHolder;
            IVestAMM.Deallocation.None, // deallocation;
            lpSchedules,
            address(0),
            poolId
        );

        return info;
    }

    function testAddRemoveLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        /* DEPLOY POOL */
        BalancerPoolData memory data = getBalancerTestData();

        /* ADD LIQUIDITY FOR THE FIRST TIME */
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 10000000;
        amountsIn[1] = 10000000;

        IVestAMMLibrary.AddLiquidity memory addLiquidityData = IVestAMMLibrary.AddLiquidity(
            data.pool,
            amountsIn,
            data.tokens
        );

        data.balancerLib.addInitialLiquidity(addLiquidityData);

        uint256 poolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 vAMMLPBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));

        // Check liquidity has been added and LP tokens balance in vAMM
        assertGt(poolLPSupply, 0);
        assertGt(vAMMLPBalance, 0);

        /* ADD LIQUIDITY FOR THE SECOND TIME */
        amountsIn[0] = 30000000;
        amountsIn[1] = 30000000;

        addLiquidityData = IVestAMMLibrary.AddLiquidity(data.pool, amountsIn, data.tokens);
        data.balancerLib.addLiquidity(addLiquidityData);

        uint256 newPoolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 newVAMMBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));

        // Check new liquidity has been added and new LP tokens balance in vAMM
        assertGt(newPoolLPSupply, poolLPSupply);
        assertGt(newVAMMBalance, vAMMLPBalance);

        // /* REMOVE SOME LIQUIDITY */
        uint256 lpTokenAmountIn = 20000000;

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = IVestAMMLibrary.RemoveLiquidity(
            data.pool,
            lpTokenAmountIn,
            data.tokens
        );
        data.balancerLib.removeLiquidity(removeLiquidityData);

        uint256 removedPoolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 removedVAMMBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));

        // TODO: need to check calculation to get exact amounts
        assertLt(removedPoolLPSupply, newPoolLPSupply);
        assertLt(removedVAMMBalance, newVAMMBalance);
        vm.stopPrank();

        // TODO Get liquidity fees
    }

    function test_checkPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        /* DEPLOY POOL */
        BalancerPoolData memory data = getBalancerTestData();

        bytes32 id = IBalancerPool(address(data.pool)).getPoolId();
        bytes32 wrongId = keccak256(abi.encodePacked(user));

        IVestAMM.VAmmInfo memory vammInfo = getVestAMMInfo(id);
        assertTrue(data.balancerLib.checkPoolExists(vammInfo), "Correct Id");

        vammInfo = getVestAMMInfo(wrongId);
        assertFalse(data.balancerLib.checkPoolExists(vammInfo), "Wrong Id");
    }
}
