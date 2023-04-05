// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {BalancerVestAMM} from "contracts/VestAMM/libraries/AmmIntegration/BalancerVestAMM.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {IBalancerPool} from "contracts/interfaces/balancer/IBalancerPool.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalancerLibraryTest is Test {
    uint256 mainnetFork;
    IERC20 Aelin = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
    IERC20 Dai = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    address user = address(0xA6B49397ce21bb62200e914F41BF371E5940Bb41);

    struct BalancerPoolData {
        string name;
        string symbol;
        IERC20[] tokens;
        uint256[] weights;
        IRateProvider[] rateProviders;
        uint256 swapFeePercentage;
        BalancerVestAMM balancerLib;
        address pool;
        bytes32 poolId;
    }

    // Alchemy url + key in .env
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function getBalancerTestData() public returns (BalancerPoolData memory) {
        IERC20[] memory tokens = new IERC20[](2);
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        uint256[] memory weights = new uint256[](2);

        tokens[0] = Dai;
        tokens[1] = Aelin;
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));
        weights[0] = 500000000000000000;
        weights[1] = 500000000000000000;

        IBalancerPool.CreateNewPool memory newPoolData = IBalancerPool.CreateNewPool(
            "aelindai",
            "AELIN-DAI",
            tokens,
            weights,
            rateProviders,
            2500000000000000 // 2,5%
        );

        BalancerVestAMM balancerLib = new BalancerVestAMM();

        address pool = balancerLib.createPool(newPoolData);
        bytes32 poolId = IBalancerPool(pool).getPoolId();

        BalancerPoolData memory data;

        data.balancerLib = balancerLib;
        data.name = "aelindai";
        data.symbol = "AELIN-DAI";
        data.tokens = tokens;
        data.weights = weights;
        data.rateProviders = rateProviders;
        data.swapFeePercentage = 2500000000000000;
        data.pool = pool;
        data.poolId = poolId;

        return data;
    }

    function testCanSetForkBlockNumber() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        BalancerPoolData memory data = getBalancerTestData();

        Aelin.transfer(address(data.balancerLib), Aelin.balanceOf(user));
        Dai.transfer(address(data.balancerLib), Dai.balanceOf(user));

        /* ADD LIQUIDITY FOR THE FIRS TIME */
        // NOTE: Since this is the First time we add liquidity => WeightedPoolUserData.JoinKind.INIT
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 10000000;
        amountsIn[1] = 10000000;

        //NOTE: poolAmountOut: Amount of LP tokens to be received from the pool
        uint256 maxBpTAmountOut = type(uint256).max;
        bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.INIT, amountsIn, maxBpTAmountOut);
        data.balancerLib.addLiquidity(data.poolId, userData);

        uint256 poolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 vAMMLPBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));
        // Check liquidity has been added
        assertGt(poolLPSupply, 0);
        // Check LP tokens balance in vAMM
        assertGt(vAMMLPBalance, 0);

        /* ADD LIQUIDITY FOR THE SECOND TIME */
        amountsIn[0] = 30000000;
        amountsIn[1] = 30000000;

        // TODO Not sure about this one. minBptAmountOut == 0
        uint256 minBptAmountOut = 0;
        userData = abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsIn, minBptAmountOut);
        data.balancerLib.addLiquidity(data.poolId, userData);

        uint256 newPoolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 newVAMMBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));
        // Check liquidity has been added
        assertGt(newPoolLPSupply, poolLPSupply);
        // Check LP tokens balance in vAMM
        assertGt(newVAMMBalance, vAMMLPBalance);

        /* REMOVE SOME LIQUIDITY FOR THE SECOND TIME */
        uint256 bptAmountIn = 20000000;

        userData = abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, bptAmountIn);
        data.balancerLib.removeLiquidity(data.poolId, userData, bptAmountIn);

        uint256 removedPoolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 removedVAMMBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));

        // TODO: need to check calculation to get exact amounts
        assertLt(removedPoolLPSupply, newPoolLPSupply);
        assertLt(removedVAMMBalance, newVAMMBalance);
        vm.stopPrank();

        // TODO Get liquidity fees
    }
}
