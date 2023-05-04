// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/libraries/AmmIntegration/SushiVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";

contract SushiLibraryTest is Test {
    uint256 mainnetFork;

    address aelinToken = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address daiToken = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = address(0x000137);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function getCreatePoolData() public returns (IVestAMMLibrary.CreateNewPool memory data) {
        IVestAMMLibrary.CreateNewPool memory data;
        address[] memory tokens = new address[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;

        data.tokens = tokens;

        return data;
    }

    function getAddLiquidityData() public returns (IVestAMMLibrary.AddLiquidity memory data) {
        IVestAMMLibrary.AddLiquidity memory data;
        address[] memory tokens = new address[](2);
        uint[] memory tokensAmtsIn = new uint[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;
        tokensAmtsIn[0] = 0.1 ether;
        tokensAmtsIn[1] = 0.1 ether;

        data.tokens = tokens;
        data.tokensAmtsIn = tokensAmtsIn;

        return data;
    }

    function getRemoveLiquidityData(uint lpTokenAmtIn) public returns (IVestAMMLibrary.RemoveLiquidity memory data) {
        IVestAMMLibrary.RemoveLiquidity memory data;
        address[] memory tokens = new address[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;

        data.tokens = tokens;
        data.lpTokenAmtIn = lpTokenAmtIn;

        return data;
    }

    function testCreatePool() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        SushiVestAMM lib = new SushiVestAMM();

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        address pool = lib.deployPool(data);

        assertFalse(pool == address(0));
    }

    function testAddLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        SushiVestAMM lib = new SushiVestAMM();

        // Emulate sending tokens to VestAMM
        IERC20(aelinToken).transfer(address(lib), 1 ether);
        IERC20(daiToken).transfer(address(lib), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        lib.deployPool(data);

        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData();
        lib.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        lib.addLiquidity(addInitialLiquidityData);
    }

    function testRemoveLiquidity() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        SushiVestAMM lib = new SushiVestAMM();

        // Emulate sending tokens to VestAMM
        IERC20(aelinToken).transfer(address(lib), 1 ether);
        IERC20(daiToken).transfer(address(lib), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        address pool = lib.deployPool(data);

        IVestAMMLibrary.AddLiquidity memory addInitialLiquidityData = getAddLiquidityData();
        lib.addInitialLiquidity(addInitialLiquidityData);

        // Add liquidity for the second time
        lib.addLiquidity(addInitialLiquidityData);

        uint256 lpTokensBalance = IERC20(pool).balanceOf(address(lib));

        assertGt(IERC20(pool).balanceOf(address(lib)), 0);

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = getRemoveLiquidityData(lpTokensBalance);
        lib.removeLiquidity(removeLiquidityData);

        assertEq(IERC20(pool).balanceOf(address(lib)), 0);
    }

    function testCheckPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        SushiVestAMM lib = new SushiVestAMM();

        // Emulate sending tokens to VestAMM
        IERC20(aelinToken).transfer(address(lib), 1 ether);
        IERC20(daiToken).transfer(address(lib), 1 ether);

        IVestAMMLibrary.CreateNewPool memory data = getCreatePoolData();
        address pool = lib.deployPool(data);

        IVestAMM.AmmData memory ammData = IVestAMM.AmmData(address(lib), aelinToken, daiToken);
        assertTrue(lib.checkPoolExists(ammData));
    }
}
