// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/libraries/AmmIntegration/CurveVestAMM.sol";

contract DerivedCurveVestAMM {
    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) public returns (address) {
        return CurveVestAMM.deployPool(_newPool);
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
        return CurveVestAMM.addInitialLiquidity(_addLiquidityData);
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
        return CurveVestAMM.addLiquidity(_addLiquidityData);
    }

    function removeLiquidity(IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData) external {
        CurveVestAMM.removeLiquidity(_removeLiquidityData);
    }

    function checkPoolExists(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (bool) {
        return CurveVestAMM.checkPoolExists(_vammInfo);
    }
}

contract CurveLibraryTest is Test {
    uint256 mainnetFork;

    address aelinToken = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address daiToken = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = address(0x000137);

    ICurveFactory factory = ICurveFactory(address(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99));

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

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

    function getVestAMMInfo(
        address poolAddress,
        address investmentToken,
        address baseToken
    ) public pure returns (IVestAMM.VAmmInfo memory) {
        IVestAMM.AmmData memory ammData = IVestAMM.AmmData(address(0), investmentToken, baseToken);

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
            poolAddress,
            0
        );

        return info;
    }

    function testBasicProcess() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        PoolData memory data = getPoolData();

        DerivedCurveVestAMM curveLibrary = new DerivedCurveVestAMM();

        // Create Pool
        address pool = curveLibrary.deployPool(data.newPoolData);

        IERC20 lpToken = IERC20(ICurvePool(pool).token());

        IERC20(aelinToken).approve(address(curveLibrary), type(uint256).max);
        IERC20(daiToken).approve(address(curveLibrary), type(uint256).max);

        /* ADD LIQUIDITY FOR THE FIRST TIME */
        // Amounts must match initial_price (500000000000000000)
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 0.5 ether;
        amountsIn[1] = 0.25 ether;

        IVestAMMLibrary.AddLiquidity memory addLiquidityData = IVestAMMLibrary.AddLiquidity(pool, amountsIn, data.coins);

        // Add liquidity for the first time (no fees are applied)
        curveLibrary.addInitialLiquidity(addLiquidityData);

        /* ADD LIQUIDITY FOR THE SECOND TIME */
        curveLibrary.addLiquidity(addLiquidityData);

        /* REMOVE ALL LIQUIDITY */
        uint256 lpTokenAmountIn = lpToken.balanceOf(address(curveLibrary)); // trying to remove all liquidity

        assertTrue(lpTokenAmountIn > 0);

        IVestAMMLibrary.RemoveLiquidity memory removeLiquidityData = IVestAMMLibrary.RemoveLiquidity(
            pool,
            lpTokenAmountIn,
            data.coins
        );

        curveLibrary.removeLiquidity(removeLiquidityData);

        lpTokenAmountIn = lpToken.balanceOf(address(curveLibrary));
        assertTrue(lpTokenAmountIn == 0);
    }

    function testCheckPoolExists() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        PoolData memory data = getPoolData();

        DerivedCurveVestAMM curveLibrary = new DerivedCurveVestAMM();

        address pool = curveLibrary.deployPool(data.newPoolData);

        IVestAMM.VAmmInfo memory vammInfo = getVestAMMInfo(pool, data.coins[0], data.coins[1]);
        assertTrue(curveLibrary.checkPoolExists(vammInfo));

        vammInfo = getVestAMMInfo(pool, address(user), address(user));
        assertFalse(curveLibrary.checkPoolExists(vammInfo));
    }
}
