// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {BalancerVestAMM} from "contracts/VestAMM/libraries/AmmIntegration/BalancerVestAMM.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMLibrary} from "./utils/VestAMMLibrary.sol";
import {IBalancerPool} from "contracts/VestAMM/interfaces/balancer/IBalancerPool.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";

contract BalancerLibraryTest is AelinVestAMMTest {
    function getCreateBalancerPoolData() public returns (IVestAMMLibrary.CreateNewPool memory) {
        address[] memory tokens = new address[](2);
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        uint256[] memory normalizedWeights = new uint256[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;
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
            address(0),
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

        return newPoolData;
    }

    function testCreatePool() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address balancerLibraryAddress = deployCode("BalancerVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(balancerLibraryAddress);

        IVestAMMLibrary.CreateNewPool memory data = getCreateBalancerPoolData();

        // Create Pool
        address pool = vestAMM.deployPool(data);

        assertFalse(pool == address(0));
    }

    function testAddLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user, user);

        address balancerLibraryAddress = deployCode("BalancerVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(balancerLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(daiToken, address(vestAMM), 1 ether);
        deal(aelinToken, address(vestAMM), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreateBalancerPoolData();

        // Create Pool
        address pool = vestAMM.deployPool(data);

        // Amounts in should match "initial_price" ratio
        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(pool, 0.5 ether, 0.5 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        vestAMM.addLiquidity(addInitialLiquidityData);
    }

    function testRemoveLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address balancerLibraryAddress = deployCode("BalancerVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(balancerLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(daiToken, address(vestAMM), 1 ether);
        deal(aelinToken, address(vestAMM), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreateBalancerPoolData();

        // Create Pool
        address pool = vestAMM.deployPool(data);

        // Amounts in should match "initial_price" ratio
        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(pool, 0.5 ether, 0.5 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        // Remove All liquidity
        uint256 lpTokenAmountIn = IERC20(pool).balanceOf(address(vestAMM));

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = getRemoveLiquidityData(pool, pool, lpTokenAmountIn);

        vestAMM.removeLiquidity(removeLiquidityData);
    }

    function testCheckPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address balancerLibraryAddress = deployCode("BalancerVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(balancerLibraryAddress);

        IVestAMMLibrary.CreateNewPool memory data = getCreateBalancerPoolData();

        // Create Pool
        address pool = vestAMM.deployPool(data);

        bytes32 id = IBalancerPool(pool).getPoolId();
        bytes32 wrongId = keccak256(abi.encodePacked(user));

        IVestAMM.VAmmInfo memory vammInfo = getVestAMMInfo(pool, daiToken, aelinToken, balancerLibraryAddress, id);
        assertTrue(vestAMM.checkPoolExists(vammInfo), "Correct Id");

        vammInfo = getVestAMMInfo(pool, daiToken, aelinToken, balancerLibraryAddress, wrongId);
        assertFalse(vestAMM.checkPoolExists(vammInfo), "Wrong Id");
    }
}
