// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {BalancerVestAMM} from "contracts/VestAMM/libraries/AmmIntegration/BalancerVestAMM.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

import "contracts/VestAMM/interfaces/balancer/IBalancerPool.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DerivedBalancerVestAMM is BalancerVestAMM {
    function createPool(IBalancerPool.CreateNewPool memory _newPool) public returns (address) {
        return _createPool(_newPool);
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
        IERC20[] tokens;
        uint256[] normalizedWeights;
        IRateProvider[] rateProviders;
        uint256 swapFeePercentage;
        BalancerVestAMM balancerLib;
        address pool;
    }

    // Alchemy url + key in .env
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function getBalancerTestData(uint256[] memory tokenAmtsIn) public returns (BalancerPoolData memory) {
        IERC20[] memory tokens = new IERC20[](2);
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        uint256[] memory normalizedWeights = new uint256[](2);

        tokens[0] = Dai;
        tokens[1] = Aelin;
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));
        normalizedWeights[0] = 500000000000000000;
        normalizedWeights[1] = 500000000000000000;

        IVestAMMLibrary.CreateNewPool memory newPoolData = IVestAMMLibrary.CreateNewPool(
            "aelindai",
            "AELIN-DAI",
            tokens,
            tokenAmtsIn,
            normalizedWeights,
            rateProviders,
            2500000000000000, // 2,5%
            address(0) // OWNER: Do we need this?
        );

        DerivedBalancerVestAMM balancerLib = new DerivedBalancerVestAMM();

        // First we need to approve the VestAMM(or the library for this test case) to use user's tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].approve(address(balancerLib), type(uint256).max);
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

    function testCanSetForkBlockNumber() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        /* DEPLOY POOL (LIQUIDITY IS ADDED FOR THE FIRST TIME) */
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 10000000;
        amountsIn[1] = 10000000;

        BalancerPoolData memory data = getBalancerTestData(amountsIn);

        uint256 poolLPSupply = IBalancerPool(data.pool).getActualSupply();
        uint256 vAMMLPBalance = IBalancerPool(data.pool).balanceOf(address(data.balancerLib));

        // Check liquidity has been added and LP tokens balance in vAMM
        assertGt(poolLPSupply, 0);
        assertGt(vAMMLPBalance, 0);

        /* ADD LIQUIDITY FOR THE SECOND TIME */
        amountsIn[0] = 30000000;
        amountsIn[1] = 30000000;

        IVestAMMLibrary.AddLiquidity memory addLiquidityData = IVestAMMLibrary.AddLiquidity(data.pool, amountsIn);
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
            lpTokenAmountIn
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
}
