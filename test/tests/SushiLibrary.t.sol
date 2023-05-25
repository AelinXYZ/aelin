// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {AelinVestAMMTest} from "./utils/AelinVestAMMTest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/libraries/AmmIntegration/SushiVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import {VestAMMLibrary} from "./utils/VestAMMLibrary.sol";

contract SushiLibraryTest is AelinVestAMMTest {
    function testCreatePool() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary lib = new VestAMMLibrary(sushiLibraryAddress);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        address pool = lib.deployPool(data);

        assertFalse(pool == address(0));
    }

    function testAddLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(sushiLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(daiToken, address(vestAMM), 1 ether);
        deal(aelinToken, address(vestAMM), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        vestAMM.deployPool(data);

        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(address(0), 0.5 ether, 0.5 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        vestAMM.addLiquidity(addInitialLiquidityData);
    }

    function testRemoveLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(sushiLibraryAddress);

        // Asume vestAMM has investmentToken and base tokens
        deal(daiToken, address(vestAMM), 1 ether);
        deal(aelinToken, address(vestAMM), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();

        address pool = vestAMM.deployPool(data);

        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData(address(0), 0.5 ether, 0.5 ether);
        vestAMM.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        vestAMM.addLiquidity(addInitialLiquidityData);

        uint256 lpTokensBalance = IERC20(pool).balanceOf(address(vestAMM));

        assertGt(IERC20(pool).balanceOf(address(vestAMM)), 0);

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = getRemoveLiquidityData(
            address(0),
            address(pool),
            lpTokensBalance
        );
        vestAMM.removeLiquidity(removeLiquidityData);

        assertEq(IERC20(pool).balanceOf(address(vestAMM)), 0);
    }

    function testCheckPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        address sushiLibraryAddress = deployCode("SushiVestAMM.sol");
        VestAMMLibrary vestAMM = new VestAMMLibrary(sushiLibraryAddress);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        address pool = vestAMM.deployPool(data);

        IVestAMM.VAmmInfo memory info = getVestAMMInfo(pool, aelinToken, daiToken, sushiLibraryAddress, 0);
        assertTrue(vestAMM.checkPoolExists(info));

        info = getVestAMMInfo(pool, address(user), address(user), sushiLibraryAddress, 0);
        assertFalse(vestAMM.checkPoolExists(info));
    }
}
