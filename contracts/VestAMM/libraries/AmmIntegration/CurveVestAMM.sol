// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/curve/ICurveFactory.sol";
import "contracts/VestAMM/interfaces/curve/ICurvePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library CurveVestAMM {
    using SafeERC20 for IERC20;

    address constant curveFactoryAddress = address(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99);

    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) public returns (address) {
        ICurvePool.CreateNewPool memory newPoolParsed = _parseNewPoolParams(_newPool);

        return _createPool(newPoolParsed);
    }

    function _parseNewPoolParams(
        IVestAMMLibrary.CreateNewPool calldata _newPool
    ) internal pure returns (ICurvePool.CreateNewPool memory) {
        address[2] memory tokens = [_newPool.tokens[0], _newPool.tokens[1]];

        return
            ICurvePool.CreateNewPool(
                _newPool.name,
                _newPool.symbol,
                tokens,
                _newPool.A,
                _newPool.gamma,
                _newPool.mid_fee,
                _newPool.out_fee,
                _newPool.allowed_extra_profit,
                _newPool.fee_gamma,
                _newPool.adjustment_step,
                _newPool.admin_fee,
                _newPool.ma_half_time,
                _newPool.initial_price
            );
    }

    function _createPool(ICurvePool.CreateNewPool memory _newPool) internal returns (address) {
        ICurveFactory curveFactory = ICurveFactory(curveFactoryAddress);

        address curvePool = curveFactory.deploy_pool(
            // NOTE: if I use the variables directly, it fails due to "Stack too deep"
            // We should probably check if there are other variables we could hardcode
            "test",
            "test",
            // _newPool.name,
            // _newPool.symbol,
            _newPool.tokens,
            _newPool.A,
            _newPool.gamma,
            _newPool.mid_fee,
            _newPool.out_fee,
            _newPool.allowed_extra_profit,
            _newPool.fee_gamma,
            _newPool.adjustment_step,
            _newPool.admin_fee,
            _newPool.ma_half_time,
            _newPool.initial_price
        );

        IERC20(_newPool.tokens[0]).approve(curvePool, type(uint256).max);
        IERC20(_newPool.tokens[1]).approve(curvePool, type(uint256).max);

        return curvePool;
    }

    function addInitialLiquidity(
        IVestAMMLibrary.AddLiquidity calldata _addLiquidityData
    ) external returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(_addLiquidityData, true);
    }

    function addLiquidity(
        IVestAMMLibrary.AddLiquidity calldata _addLiquidityData
    ) external returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(_addLiquidityData, false);
    }

    function _addLiquidity(
        IVestAMMLibrary.AddLiquidity calldata _addLiquidityData,
        bool _isInitialLiquidity
    ) internal returns (uint256, uint256, uint256, uint256) {
        // NOTE: should add validation to check that tokensAmtsIn match initial_price

        ICurvePool curvePool = ICurvePool(_addLiquidityData.poolAddress);

        for (uint256 i; i < _addLiquidityData.tokens.length; i++) {
            IERC20(_addLiquidityData.tokens[i]).transferFrom(msg.sender, address(this), _addLiquidityData.tokensAmtsIn[i]);
        }

        uint256[2] memory tokensAmtsIn = [_addLiquidityData.tokensAmtsIn[0], _addLiquidityData.tokensAmtsIn[1]];

        uint256 _minLpTokensOut = _isInitialLiquidity ? 0 : curvePool.calc_token_amount(tokensAmtsIn);

        uint256 lpTokens = curvePool.add_liquidity(tokensAmtsIn, _minLpTokensOut);

        IERC20(curvePool.token()).transfer(msg.sender, lpTokens);

        // TODO: should return (numInvTokensInLP, numBaseTokensInLP, numInvTokensFee, numBaseTokensFee)
        return (_addLiquidityData.tokensAmtsIn[0], _addLiquidityData.tokensAmtsIn[1], 0, 0);
    }

    function removeLiquidity(
        IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData
    ) external returns (uint256, uint256) {
        ICurvePool curvePool = ICurvePool(_removeLiquidityData.poolAddress);

        IERC20(_removeLiquidityData.lpToken).transferFrom(msg.sender, address(this), _removeLiquidityData.lpTokenAmtIn);

        uint256[2] memory minAmountsOut;
        minAmountsOut[0] = curvePool.calc_withdraw_one_coin(_removeLiquidityData.lpTokenAmtIn / 2, 0); // Remove same amount of each token by default ?
        minAmountsOut[1] = curvePool.calc_withdraw_one_coin(_removeLiquidityData.lpTokenAmtIn / 2, 1); // Remove same amount of each token by default ?

        uint256 token0AmtBefore = IERC20(_removeLiquidityData.tokens[0]).balanceOf(address(this));
        uint256 token1AmtBefore = IERC20(_removeLiquidityData.tokens[1]).balanceOf(address(this));

        //NOTE: Send tokens to user? or fees must be capture first?
        curvePool.remove_liquidity(_removeLiquidityData.lpTokenAmtIn, minAmountsOut);

        uint256 token0AmtAfter = IERC20(_removeLiquidityData.tokens[0]).balanceOf(address(this));
        uint256 token1AmtAfter = IERC20(_removeLiquidityData.tokens[1]).balanceOf(address(this));

        // Since curve "remove_liquidity" function doesn't allow to specify the amount of tokens to withdraw, we need to calculate the amount of tokens to send to the user
        // NOTE: Check if this is really needed, or we could just send all the balance of each token
        IERC20(_removeLiquidityData.tokens[0]).transfer(msg.sender, token0AmtAfter - token0AmtBefore);
        IERC20(_removeLiquidityData.tokens[1]).transfer(msg.sender, token1AmtAfter - token1AmtBefore);

        return (token0AmtAfter - token0AmtBefore, token1AmtAfter - token1AmtBefore);
    }

    function checkPoolExists(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (bool) {
        ICurveFactory curveFactory = ICurveFactory(curveFactoryAddress);

        address pool = curveFactory.find_pool_for_coins(_vammInfo.ammData.investmentToken, _vammInfo.ammData.baseToken, 0);

        return pool != address(0) ? true : false;
    }

    function getPriceRatio(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (uint256) {
        ICurveFactory curveFactory = ICurveFactory(curveFactoryAddress);

        address pool = curveFactory.find_pool_for_coins(_vammInfo.ammData.investmentToken, _vammInfo.ammData.baseToken, 0);

        ICurvePool curvePool = ICurvePool(pool);

        return curvePool.get_dy(0, 1, 1 ether);
    }
}
