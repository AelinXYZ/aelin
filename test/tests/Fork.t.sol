// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {BalancerVestAMM} from "contracts/VestAMM/libraries/AmmIntegration/BalancerTestLib.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20 {
    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);
}

interface BalancerPool {
    function getPoolId() external view returns (bytes32);

    function getActualSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

contract ForkTest is Test {
    // the identifiers of the forks
    uint256 mainnetFork;
    uint256 optimismFork;
    IERC20 Aelin = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
    IERC20 Dai = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    address user = address(0xA6B49397ce21bb62200e914F41BF371E5940Bb41);

    function setUp() public {
        mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/EW9N4oDCQJ58k_9wF-wG8pkq7amdPnqD");
    }

    function testCanSetForkBlockNumber() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        BalancerVestAMM balancerLib = new BalancerVestAMM(
            address(0xBA12222222228d8Ba445958a75a0704d566BF2C8),
            address(0x5Dd94Da3644DDD055fcf6B3E1aa310Bb7801EB8b)
        );

        address pool = balancerLib.createPool();

        bytes32 poolId = BalancerPool(pool).getPoolId();

        Aelin.transfer(address(balancerLib), Aelin.balanceOf(user));
        Dai.transfer(address(balancerLib), Dai.balanceOf(user));

        /* ADD LIQUIDITY FOR THE FIRS TIME */
        // Since this is the First time we add liquidity => WeightedPoolUserData.JoinKind.INIT
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 10000000;
        amountsIn[1] = 10000000;

        //poolAmountOut Amount of LP tokens to be received from the pool
        uint256 maxBpTAmountOut = type(uint256).max;
        bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.INIT, amountsIn, maxBpTAmountOut);
        balancerLib.addLiquidity(poolId, userData);

        uint256 poolLPSupply = BalancerPool(pool).getActualSupply();
        uint256 vAMMLPBalance = BalancerPool(pool).balanceOf(address(balancerLib));
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
        balancerLib.addLiquidity(poolId, userData);

        uint256 newPoolLPSupply = BalancerPool(pool).getActualSupply();
        uint256 newVAMMBalance = BalancerPool(pool).balanceOf(address(balancerLib));
        // Check liquidity has been added
        assertGt(newPoolLPSupply, poolLPSupply);
        // Check LP tokens balance in vAMM
        assertGt(newVAMMBalance, vAMMLPBalance);

        /* REMOVE SOME LIQUIDITY FOR THE SECOND TIME */
        uint256 bptAmountIn = 20000000;

        console.log("poolLPSupply", newPoolLPSupply);
        console.log("vAMMLPBalance", newVAMMBalance);

        userData = abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, bptAmountIn);
        balancerLib.removeLiquidity(poolId, userData, bptAmountIn);

        uint256 removedPoolLPSupply = BalancerPool(pool).getActualSupply();
        uint256 removedVAMMBalance = BalancerPool(pool).balanceOf(address(balancerLib));

        console.log("removedPoolLPSupply", removedPoolLPSupply);
        console.log("removedVAMMBalance", removedVAMMBalance);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = Aelin;
        tokens[1] = Dai;

        // TODO Get liquidity fees
        vm.stopPrank();
    }
}
