// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/sushi/ISushiFactory.sol";
import "contracts/VestAMM/interfaces/sushi/ISushiRouter.sol";
import "contracts/VestAMM/interfaces/sushi/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

// NOTE: This should be a lirbary. But atmm it's not possible to test the whole process with a library.
contract SushiVestAMM {
    using SafeERC20 for IERC20;

    address constant sushiFactoryV2Address = address(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    address constant sushiRouterV2Address = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    uint256 constant DEADLINE = 20 minutes;

    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) external returns (address) {
        return _createPool(_newPool);
    }

    function _createPool(IVestAMMLibrary.CreateNewPool calldata _newPool) internal returns (address) {
        ISushiFactory sushiFactory = ISushiFactory(sushiFactoryV2Address);
        ISushiRouter sushiRouterV2 = ISushiRouter(sushiRouterV2Address);

        address sushiPool = sushiFactory.createPair(_newPool.tokens[0], _newPool.tokens[1]);

        IERC20(_newPool.tokens[0]).approve(address(sushiRouterV2), type(uint256).max);
        IERC20(_newPool.tokens[1]).approve(address(sushiRouterV2), type(uint256).max);
        IERC20(sushiPool).approve(address(sushiRouterV2), type(uint256).max);

        return sushiPool;
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
        // NOTE The price ratio is set when adding liquidity for the first time.
        // Once that is set, the following liquidity additions must use the same ratio.
        uint[] memory minAmtsToLp = new uint[](2); // minAmtsToLp = [0,0] for the first liquidity addition. The amount to LP will always be the desired amount
        return _addLiquidity(_addLiquidityData, minAmtsToLp);
    }

    // NOTE Have to add token addresses to IVestAMMLibrary.AddLiquidity
    function addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        ISushiRouter sushiRouterV2 = ISushiRouter(sushiRouterV2Address);
        ISushiFactory sushiFactory = ISushiFactory(sushiFactoryV2Address);

        uint[] memory minAmtsToLp = new uint[](2);

        // NOTE Here we're calculating the minimum amounts we want to LP, but this might be done be the client.
        // Also need to double check the logic
        address pool = sushiFactory.getPair(_addLiquidityData.tokens[0], _addLiquidityData.tokens[1]);
        (uint reserveA, uint reserveB, ) = IUniswapV2Pair(pool).getReserves();

        minAmtsToLp[0] = sushiRouterV2.quote(_addLiquidityData.tokensAmtsIn[1], reserveA, reserveB);
        minAmtsToLp[1] = sushiRouterV2.quote(_addLiquidityData.tokensAmtsIn[0], reserveA, reserveB);

        return _addLiquidity(_addLiquidityData, minAmtsToLp);
    }

    function _addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData, uint[] memory _minAmtsToLp)
        internal
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        //NOTE Some pools have staking available. For this version we will not support staking.
        for (uint256 i; i < _addLiquidityData.tokens.length; i++) {
            IERC20(_addLiquidityData.tokens[i]).transferFrom(msg.sender, address(this), _addLiquidityData.tokensAmtsIn[i]);
        }

        // Add liquidity to pool via Router
        ISushiRouter sushiRouterV2 = ISushiRouter(sushiRouterV2Address);

        // NOTE In sushi (not curve or balancer) it is possible to use ETH as one of the tokens. In our case the investment token.
        // For simplicity, and to be inline with other libraries we will not support ETH as one of the tokens, only WETH.
        (uint amountA, uint amountB, uint liquidity) = sushiRouterV2.addLiquidity(
            _addLiquidityData.tokens[0],
            _addLiquidityData.tokens[1],
            _addLiquidityData.tokensAmtsIn[0],
            _addLiquidityData.tokensAmtsIn[1],
            _minAmtsToLp[0],
            _minAmtsToLp[1],
            msg.sender, // lpTokens sent to vestAMM
            block.timestamp + DEADLINE
        );

        uint numBaseTokensInLP = _convertTokenToLP(amountA, IERC20Decimals(_addLiquidityData.tokens[0]).decimals());
        uint numInvTokensInLP = _convertTokenToLP(amountB, IERC20Decimals(_addLiquidityData.tokens[1]).decimals());

        return (numInvTokensInLP, numBaseTokensInLP, 0, 0);
    }

    function removeLiquidity(IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData)
        external
        returns (uint256, uint256)
    {
        ISushiRouter sushiRouterV2 = ISushiRouter(sushiRouterV2Address);

        IERC20(_removeLiquidityData.lpToken).transferFrom(msg.sender, address(this), _removeLiquidityData.lpTokenAmtIn);

        address[] memory path = new address[](2);
        path[0] = _removeLiquidityData.tokens[0];
        path[1] = _removeLiquidityData.tokens[1];

        uint[] memory amountsMin = sushiRouterV2.getAmountsOut(_removeLiquidityData.lpTokenAmtIn, path);

        (uint256 token0Amt, uint256 token1Amt) = sushiRouterV2.removeLiquidity(
            _removeLiquidityData.tokens[0],
            _removeLiquidityData.tokens[1],
            _removeLiquidityData.lpTokenAmtIn,
            amountsMin[0],
            amountsMin[1],
            msg.sender, // investmentToken + baseToken sent to vestAMM
            block.timestamp + DEADLINE
        );

        return (token0Amt, token1Amt);
    }

    function checkPoolExists(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (bool) {
        ISushiFactory sushiFactory = ISushiFactory(sushiFactoryV2Address);

        address pool = sushiFactory.getPair(_vammInfo.ammData.baseToken, _vammInfo.ammData.investmentToken);

        return pool != address(0);
    }

    function _convertTokenToLP(uint256 _tokenAmount, uint256 _investmentTokenDecimals) internal pure returns (uint256) {
        return _tokenAmount * 10**(18 - _investmentTokenDecimals);
    }
}
