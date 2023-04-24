
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICurveFactory {
    function deploy_pool(
        string memory _name,
        string memory _symbol,
        address[2] memory _coins,
        uint256 A,
        uint256 gamma,
        uint256 mid_fee,
        uint256 out_fee,
        uint256 allowed_extra_profit,
        uint256 fee_gamma,
        uint256 adjustment_step,
        uint256 admin_fee,
        uint256 ma_half_time,
        uint256 initial_price
    ) external returns(address);
}

interface ICurvePool {
    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount
    ) external returns(uint256);

    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts, bool use_eth, address receiver) external;

    function calc_token_amount(uint256[2] memory _amounts) external view returns(uint256);
    
    function calc_withdraw_one_coin(uint256 token_amount, uint256 i) external returns(uint256);

    function token() external view returns(address);

    function fee() external view returns(uint256);
}


contract CurveLibrary is Test {
    uint256 mainnetFork;

    address aelinToken = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address daiToken = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // address user = address(0xA6B49397ce21bb62200e914F41BF371E5940Bb41);
    address user = address(0x000137);
    
    ICurveFactory factory = ICurveFactory(address(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99));

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    struct PoolData {
        string name;
        string symbol;
        address[2] coins;
        uint256 A;
        uint256 gamma;
        uint256 mid_fee;
        uint256 out_fee;
        uint256 allowed_extra_profit;
        uint256 fee_gamma;
        uint256 adjustment_step;
        uint256 admin_fee;
        uint256 ma_half_time;
        uint256 initial_price;
    }

    function getPoolData() public returns (PoolData memory) {
        PoolData memory data;

        address[] memory coins = new address[](2); 

        coins[0] = aelinToken;
        coins[1] = daiToken;
        
        data.name = "AelinDai";
        data.symbol = "AELDAI";
        data.coins[0] = coins[0];
        data.coins[1] = coins[1];
        data.A = 400000;
        data.gamma = 72500000000000;
        data.mid_fee = 26000000;
        data.out_fee = 45000000;
        data.allowed_extra_profit = 2000000000000;
        data.fee_gamma = 230000000000000;
        data.adjustment_step = 146000000000000;
        data.admin_fee = 5000000000;
        data.ma_half_time = 600;
        data.initial_price = 500000000000000000; // To/T1 = 0.5

        return data;
    }

    function testCoins() public {
        vm.selectFork(mainnetFork);
        vm.startPrank(user);

        deal(aelinToken, user, 1 ether);
        deal(daiToken, user, 1 ether);

        PoolData memory data = getPoolData();

        // Create Pool
        address pool = factory.deploy_pool(
            "Test",
            "Test",
            data.coins,
            data.A,
            data.gamma,
            data.mid_fee,
            data.out_fee,
            data.allowed_extra_profit,
            data.fee_gamma,
            data.adjustment_step,
            data.admin_fee,
            data.ma_half_time,
            data.initial_price
        );

        ICurvePool curvePool = ICurvePool(pool);
        IERC20 lpToken = IERC20(curvePool.token());

        IERC20(aelinToken).approve(pool, type(uint256).max);
        IERC20(daiToken).approve(pool, type(uint256).max);

        uint256[2] memory amountsIn;
        amountsIn[0] = 0.5 ether;
        amountsIn[1] = 0.25 ether;

        // Add liquidity for the first time (no fees are applied)
        uint256 lpTokensFirst = curvePool.add_liquidity(
            amountsIn,
            0 // NOTE: on initial liquidity add, this is allways 0
        );

        assertGt(lpTokensFirst, 0, "LP tokens should be greater than 0");
        
        // Next time we add liquidity, we need to pass the amount of LP tokens we want to mint
        uint256 minLpTokensOut = curvePool.calc_token_amount(amountsIn);
        uint256 fee = curvePool.fee();
      
        // Add liquidity for the second time (fees are applied)
        // base_fee: uint256 = self.fee * N_COINS / (4 * (N_COINS - 1))
        // base_fee = 44987868 * (2 / (4 * (2 - 1))) = 44987868 * 0.5 = 22493934
        uint256 lpTokensSecond = curvePool.add_liquidity(
            amountsIn,
            minLpTokensOut
        );

        assertGe(lpTokensSecond, minLpTokensOut);

        // Remove liquidity
        uint256 initialAelinBalance =  IERC20(aelinToken).balanceOf(user);
        uint256 initialDaiBalance =  IERC20(daiToken).balanceOf(user);

        // Deposited ALL Aelin
        assertEq(initialAelinBalance, 0);

        uint lpTokenAmountIn = lpToken.balanceOf(user); // trying to remove all liquidity

        uint256[2] memory minAmountsOut;
        minAmountsOut[0] = curvePool.calc_withdraw_one_coin(lpTokenAmountIn / 2, 0);
        minAmountsOut[1] = curvePool.calc_withdraw_one_coin(lpTokenAmountIn / 2, 1);

        // minAmountsOut[0] = 0;
        // minAmountsOut[1] = 0;

        curvePool.remove_liquidity(lpTokenAmountIn, minAmountsOut, false, user);

        uint256 finalAelinBalance =  IERC20(aelinToken).balanceOf(user);

        // Got back ALL Aelin (minus fees)
        // TODO: investigate how to get charged fees
        assertGt(finalAelinBalance, 0);
    }
}
