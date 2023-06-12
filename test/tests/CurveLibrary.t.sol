// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import {VestAMMLibrary} from "./utils/VestAMMLibrary.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import "contracts/VestAMM/interfaces/curve/ICurvePool.sol";

contract CurveLibraryTest is AelinVestAMMTest {
    struct PoolData {
        string name;
        string symbol;
        address[] coins;
        IVestAMMLibrary.CreateNewPool newPoolData;
    }

    function getPoolData() public view returns (PoolData memory) {
        PoolData memory data;

        address[] memory coins = new address[](2);
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        uint256[] memory normalizedWeights = new uint256[](2);

        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));
        normalizedWeights[0] = 0;
        normalizedWeights[1] = 0;

        coins[0] = aelinToken;
        coins[1] = daiToken;

        data.name = "AelinDai";
        data.symbol = "AELDAI";
        data.coins = coins;

        IVestAMMLibrary.CreateNewPool memory newPoolData = IVestAMMLibrary.CreateNewPool(
            "aelindai",
            "AELIN-DAI",
            coins,
            normalizedWeights,
            rateProviders,
            0,
            address(0), // OWNER: Do we need this?,
            400000,
            72500000000000,
            26000000,
            45000000,
            2000000000000,
            230000000000000,
            146000000000000,
            5000000000,
            600,
            500000000000000000
        );

        data.newPoolData = newPoolData;

        return data;
    }

    function testCreatePool() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address curveLibraryAddress = deployCode("CurveVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(curveLibraryAddress);

        PoolData memory data = getPoolData();

        // Create Pool
        address pool = vestAMM.deployPool(data.newPoolData);

        assertFalse(pool == address(0));
    }

    function testAddLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address curveLibraryAddress = deployCode("CurveVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(curveLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(daiToken, address(vestAMM), 1 ether);
        deal(aelinToken, address(vestAMM), 1 ether);

        PoolData memory data = getPoolData();
        address pool = vestAMM.deployPool(data.newPoolData);

        // Amounts in should match "initial_price" ratio
        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(pool, 0.5 ether, 0.25 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        vestAMM.addLiquidity(addInitialLiquidityData);
    }

    function testRemoveLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address curveLibraryAddress = deployCode("CurveVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(curveLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(aelinToken, address(vestAMM), 0.5 ether);
        deal(daiToken, address(vestAMM), 0.25 ether);

        PoolData memory data = getPoolData();
        address pool = vestAMM.deployPool(data.newPoolData);

        // Amounts in should match "initial_price" ratio
        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(pool, 0.5 ether, 0.25 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        assertTrue(IERC20(aelinToken).balanceOf(address(vestAMM)) == 0);
        assertTrue(IERC20(daiToken).balanceOf(address(vestAMM)) == 0);

        /* REMOVE ALL LIQUIDITY */
        IERC20 lpToken = IERC20(ICurvePool(pool).token());
        uint256 lpTokenAmountIn = lpToken.balanceOf(address(vestAMM)); // trying to remove all liquidity
        assertTrue(lpTokenAmountIn > 0);

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = getRemoveLiquidityData(
            pool,
            address(lpToken),
            lpTokenAmountIn
        );

        vestAMM.removeLiquidity(removeLiquidityData);

        lpTokenAmountIn = lpToken.balanceOf(address(vestAMM));
        assertTrue(lpTokenAmountIn == 0);
        assertTrue(IERC20(aelinToken).balanceOf(address(vestAMM)) > 0);
        assertTrue(IERC20(daiToken).balanceOf(address(vestAMM)) > 0);
    }

    function testCheckPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        PoolData memory data = getPoolData();

        address curveLibraryAddress = deployCode("CurveVestAMM.sol");
        VestAMMLibrary curveLibrary = new VestAMMLibrary(curveLibraryAddress);

        address pool = curveLibrary.deployPool(data.newPoolData);

        IVestAMM.VAmmInfo memory vammInfo = getVestAMMInfo(pool, data.coins[0], data.coins[1], curveLibraryAddress, 0);
        assertTrue(curveLibrary.checkPoolExists(vammInfo));

        vammInfo = getVestAMMInfo(pool, address(user), address(user), curveLibraryAddress, 0);
        assertFalse(curveLibrary.checkPoolExists(vammInfo));
        vm.stopPrank();
    }
}
