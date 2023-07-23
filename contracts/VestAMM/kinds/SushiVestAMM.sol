// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/sushi/ISushiFactory.sol";
import "contracts/VestAMM/interfaces/sushi/ISushiRouter.sol";
import "contracts/VestAMM/interfaces/sushi/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Decimals} from "../interfaces/IERC20Decimals.sol";
import {VestAMM} from "../VestAMM.sol";

contract SushiVestAMM is VestAMM {
    using SafeERC20 for IERC20;

    ISushiFactory constant sushiFactoryV2 = ISushiFactory(address(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac));
    ISushiRouter constant sushiRouterV2 = ISushiRouter(address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F));
    IUniswapV2Pair public sushiPool;
    uint256 constant DEADLINE = 20 minutes;

    ///////////
    // Hooks //
    ///////////

    function init() internal override returns (bool) {
        sushiPool = IUniswapV2Pair(vAmmInfo.poolAddress);

        return true;
    }

    function checkPoolExists() internal override returns (bool) {
        address pool = sushiFactoryV2.getPair(vAmmInfo.ammData.baseToken, vAmmInfo.ammData.investmentToken);
        return pool != address(0);
    }

    function deployPool() internal override returns (address) {
        address sushiPoolAddress = sushiFactoryV2.createPair(vAmmInfo.ammData.baseToken, vAmmInfo.ammData.investmentToken);

        IERC20(vAmmInfo.ammData.baseToken).approve(address(sushiRouterV2), type(uint256).max);
        IERC20(vAmmInfo.ammData.investmentToken).approve(address(sushiRouterV2), type(uint256).max);
        IERC20(sushiPoolAddress).approve(address(sushiRouterV2), type(uint256).max);

        sushiPool = IUniswapV2Pair(sushiPoolAddress);

        return sushiPoolAddress;
    }

    function getPriceRatio() internal override returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = vAmmInfo.ammData.baseToken;
        path[1] = vAmmInfo.ammData.investmentToken;

        uint256[] memory ratio = sushiRouterV2.getAmountsOut(10 ** 18, path);

        return ratio[1];
    }

    function addInitialLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        // NOTE The price ratio is set when adding liquidity for the first time.
        // Once that is set, the following liquidity additions must use the same ratio.
        uint[] memory minAmtsToLp = new uint[](2); // minAmtsToLp = [0,0] for the first liquidity addition. The amount to LP will always be the desired amount
        return _addLiquidity(minAmtsToLp);
    }

    // NOTE Have to add token addresses to IVestAMMLibrary.AddLiquidity
    function addLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        AddLiquidity memory _addLiquidityData = createAddLiquidity();
        uint[] memory minAmtsToLp = new uint[](2);

        // NOTE Here we're calculating the minimum amounts we want to LP, but this might be done be the client.
        // Also need to double check the logic
        address pool = sushiFactoryV2.getPair(_addLiquidityData.tokens[0], _addLiquidityData.tokens[1]);
        (uint reserveA, uint reserveB, ) = IUniswapV2Pair(pool).getReserves();

        minAmtsToLp[0] = sushiRouterV2.quote(_addLiquidityData.tokensAmtsIn[1], reserveA, reserveB);
        minAmtsToLp[1] = sushiRouterV2.quote(_addLiquidityData.tokensAmtsIn[0], reserveA, reserveB);

        return _addLiquidity(minAmtsToLp);
    }

    function _addLiquidity(uint[] memory _minAmtsToLp) internal returns (uint256, uint256, uint256, uint256) {
        AddLiquidity memory _addLiquidityData = createAddLiquidity();
        //NOTE Some pools have staking available. For this version we will not support staking.
        for (uint256 i; i < _addLiquidityData.tokens.length; i++) {
            IERC20(_addLiquidityData.tokens[i]).transferFrom(msg.sender, address(this), _addLiquidityData.tokensAmtsIn[i]);
        }

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

    function removeLiquidity(uint256 _tokensAmtsIn) internal override returns (uint256, uint256) {
        RemoveLiquidity memory _removeLiquidityData = createRemoveLiquidity(_tokensAmtsIn);

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

    /////////////
    // Helpers //
    /////////////

    /// @dev is this correct?
    function _convertTokenToLP(uint256 _tokenAmount, uint256 _investmentTokenDecimals) internal pure returns (uint256) {
        return _tokenAmount * 10 ** (18 - _investmentTokenDecimals);
    }

    function createAddLiquidity() internal view returns (AddLiquidity memory) {
        // TODO add in the other variables needed to deploy a pool and return these values
        uint256 investmentTokenAmount = totalInvTokensDeposited < maxInvTokens ? totalInvTokensDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalInvTokensDeposited < maxInvTokens
            ? (totalBaseTokens * totalInvTokensDeposited) / maxInvTokens
            : totalBaseTokens;

        uint256[] memory tokensAmtsIn = new uint256[](2);
        tokensAmtsIn[0] = investmentTokenAmount;
        tokensAmtsIn[1] = baseTokenAmount;

        address[] memory tokens = new address[](2);
        tokens[0] = vAmmInfo.ammData.investmentToken;
        tokens[1] = vAmmInfo.ammData.baseToken;

        return AddLiquidity(vAmmInfo.poolAddress, tokensAmtsIn, tokens);
    }

    function createRemoveLiquidity(uint256 _tokensAmtsIn) internal view returns (RemoveLiquidity memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = vAmmInfo.ammData.investmentToken;
        tokens[1] = vAmmInfo.ammData.baseToken;

        return RemoveLiquidity(address(sushiPool), address(sushiPool), _tokensAmtsIn, tokens);
    }
}
