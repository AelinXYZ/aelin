// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {VestAMM} from "../VestAMM.sol";
import {IVestAMM} from "contracts/VestAMM/interfaces/IVestAMM.sol";
import {ICurveFactory} from "contracts/VestAMM/interfaces/curve/ICurveFactory.sol";
import {ICurvePool} from "contracts/VestAMM/interfaces/curve/ICurvePool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Validate} from "contracts/VestAMM/libraries/validation/VestAMMValidation.sol";

/// @dev Ensure against Curve Read-only reentrancy - https://twitter.com/danielvf/status/1682496333540741121

contract CurveVestAMM is VestAMM {
    using SafeERC20 for IERC20;

    /// @dev check this hardcoded var
    ICurveFactory constant curveFactory = ICurveFactory(address(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99));
    ICurvePool public curvePool;
    IERC20 public lpToken;

    ICurveFactory.CreateNewPool public newPoolData;

    ////////////////////
    // Curve Specific //
    ////////////////////

    /// @dev unideal 'cos it requires a seperate function to add the pool data
    ///      but this isn't easily generalisable for all pool types
    function setInitialPoolData(
        ICurveFactory.CreateNewPool memory _newPooldata
    ) external onlyHolder lpFundingWindow returns (bool) {
        Validate.liquidityLaunch(vAmmInfo.hasLaunchPhase);

        newPoolData = _newPooldata;

        return true;
    }

    ///////////
    // Hooks //
    ///////////

    function init() internal override returns (bool) {
        curvePool = ICurvePool(vAmmInfo.poolAddress);
        lpToken = IERC20(curvePool.token());

        return true;
    }

    function checkPoolExists() internal override returns (bool) {
        address pool = curveFactory.find_pool_for_coins(vAmmInfo.ammData.investmentToken, vAmmInfo.ammData.baseToken, 0);

        return pool != address(0) ? true : false;
    }

    function getPriceRatio() internal override returns (uint256) {
        return curvePool.get_dy(0, 1, 1 ether);
    }

    function deployPool() internal override returns (address) {
        //Check that pool data is set

        /// @dev stack too deep issue here
        address newCurvePool = curveFactory.deploy_pool(
            "test",
            "TEST",
            //newPoolData.name,
            //newPoolData.symbol,
            newPoolData.tokens,
            newPoolData.A,
            newPoolData.gamma,
            newPoolData.mid_fee,
            newPoolData.out_fee,
            newPoolData.allowed_extra_profit,
            newPoolData.fee_gamma,
            newPoolData.adjustment_step,
            newPoolData.admin_fee,
            newPoolData.ma_half_time,
            newPoolData.initial_price
        );
        require(newCurvePool != address(0));

        IERC20(newPoolData.tokens[0]).approve(newCurvePool, type(uint256).max);
        IERC20(newPoolData.tokens[1]).approve(newCurvePool, type(uint256).max);

        curvePool = ICurvePool(newCurvePool);

        return newCurvePool;
    }

    function addInitialLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(true);
    }

    function addLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(false);
    }

    function _addLiquidity(bool _isInitialLiquidity) internal returns (uint256, uint256, uint256, uint256) {
        AddLiquidity memory _addLiquidityData = createAddLiquidity();
        // NOTE: should add validation to check that tokensAmtsIn match initial_price
        for (uint256 i; i < _addLiquidityData.tokens.length; i++) {
            IERC20(_addLiquidityData.tokens[i]).transferFrom(msg.sender, address(this), _addLiquidityData.tokensAmtsIn[i]);
        }

        uint256[2] memory tokensAmtsIn = [_addLiquidityData.tokensAmtsIn[0], _addLiquidityData.tokensAmtsIn[1]];

        uint256 _minLpTokensOut = _isInitialLiquidity ? 0 : curvePool.calc_token_amount(tokensAmtsIn);

        uint256 lpTokens = curvePool.add_liquidity(tokensAmtsIn, _minLpTokensOut);

        // TODO: should return (numInvTokensInLP, numBaseTokensInLP, numInvTokensFee, numBaseTokensFee)
        return (_addLiquidityData.tokensAmtsIn[0], _addLiquidityData.tokensAmtsIn[1], 0, 0);
    }

    function removeLiquidity(uint256 _tokensAmtsIn) internal override returns (uint256, uint256) {
        /// @dev double check some of this logic

        RemoveLiquidity memory _removeLiquidityData = createRemoveLiquidity(_tokensAmtsIn);

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

    /////////////
    // Helpers //
    /////////////

    /**
     * @dev a helper function to create a struct for adding liquidiy that lives in memory
     */
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

        return RemoveLiquidity(address(curvePool), address(lpToken), _tokensAmtsIn, tokens);
    }
}
