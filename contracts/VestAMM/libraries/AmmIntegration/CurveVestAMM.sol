
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import "contracts/VestAMM/interfaces/curve/ICurveFactory.sol";
import "contracts/VestAMM/interfaces/curve/ICurvePool.sol";

library CurveLibrary {
    address constant curveFactoryAddress = address(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99);

    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) public returns (address) {
        ICurvePool.CreateNewPool memory newPoolParsed = _parseNewPoolParams(_newPool);

        return _createPool(newPoolParsed);
    }

    function _parseNewPoolParams(IVestAMMLibrary.CreateNewPool calldata _newPool)
        internal
        pure
        returns (ICurvePool.CreateNewPool memory)
    {
        return
            ICurvePool.CreateNewPool({
                _newPool.name,
                _newPool.symbol,
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
            });
    }

    function _createPool (ICurvePool.CreateNewPool _newPool) internal returns (address) {
        ICurveFactory curveFactory = ICurveFactory(curveFactoryAddress);
        
        address curvePool =  curveFactory.new_pool(
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

        IERC20(tokens[0]).approve(curvePool, type(uint256).max);
        IERC20(tokens[1]).approve(curvePool, type(uint256).max);

        return curvePool;
    }

    function addInitialLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData) external returns(uint256, uint256, uint256, uint256) {
        return _addLiquidity(_addLiquidityData, 0);
    }

    function addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData) external returns(uint256, uint256, uint256, uint256) {
        ICurvePool curvePool = ICurvePool(_addLiquidityData.poolAddress);
        uint256 minLpTokensOut = curvePool.calc_token_amount(_addLiquidityData.amountsIn);

        return _addLiquidity(_addLiquidityData, minLpTokensOut);
    }

    function _addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData, uint256 _minLpTokensOut) internal returns(uint256, uint256, uint256, uint256) {
        ICurvePool curvePool = ICurvePool(_addLiquidityData.poolAddress);

        uint256 lpTokens = curvePool.add_liquidity(
            _addLiquityData.amountsIn,
            _minLpTokensOut
        );

        // TODO: should return (numInvTokensInLP, numBaseTokensInLP, numInvTokensFee, numBaseTokensFee)
        return (_addLiquidityData.amountsIn[0], _addLiquidityData.amountsIn[1], 0, 0);
    }

    function removeLiquidity(IVestAMMLibrary.AddLiquidity calldata _removeLiquidityData) external {
        ICurvePool curvePool = ICurvePool(_removeLiquidityData.pool);

        uint256[2] memory minAmountsOut;
        minAmountsOut[0] = curvePool.calc_withdraw_one_coin(_removeLiquidityDatA.lpTokenAmountIn / 2, 0); // Remove same amount of each token by default ?
        minAmountsOut[1] = curvePool.calc_withdraw_one_coin(_removeLiquidityDatA.lpTokenAmountIn / 2, 1); // Remove same amount of each token by default ?
        
        //NOTE: Send tokens to user? or fees must be capture first?
        curvePool.remove_liquidity(_removeLiquidityDatA.lpTokenAmountIn, minAmountsOut, false, msg.sender);
    }

    function checkPoolExists(address curvePool) external view returns(bool) {
        ICurveFactory curveFactory = ICurveFactory(curveFactoryAddress);

        address pool = curveFactory.find_pool_for_coins(
            ICurvePool(curvePool).token(0),
            ICurvePool(curvePool).token(1),
            0
        );

        return pool != address(0) ? true : false;
    }
}

