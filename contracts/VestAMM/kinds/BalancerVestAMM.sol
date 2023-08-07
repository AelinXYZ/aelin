// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {VestAMM} from "../VestAMM.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/interfaces/balancer/IWeightedPoolFactory.sol";
import "contracts/VestAMM/interfaces/balancer/IVault.sol";
import "contracts/VestAMM/interfaces/balancer/IBalancerPool.sol";
import "contracts/VestAMM/interfaces/balancer/IAsset.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import {Validate} from "contracts/VestAMM/libraries/VestAMMValidation.sol";

contract BalancerVestAMM is VestAMM {
    /// @dev check hardcoding here???
    IWeightedPoolFactory internal constant weightedPoolFactory =
        IWeightedPoolFactory(address(0x897888115Ada5773E02aA29F775430BFB5F34c51));
    IVault internal constant balancerVault = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

    /// @dev is the pool address the same as the lp token?
    IBalancerPool public balancerPool;

    IBalancerPool.CreateNewPool public newPoolData;

    ///////////////////////
    // Balancer Specific //
    ///////////////////////

    /// @dev unideal 'cos it requires a seperate function to add the pool data
    ///      but this isn't easily generalisable for all pool types
    function setInitialPoolData(
        IBalancerPool.CreateNewPool memory _newPooldata
    ) external onlyHolder lpFundingWindow returns (bool) {
        Validate.liquidityLaunch(vAmmInfo.hasLaunchPhase);

        newPoolData = _newPooldata;

        return true;
    }

    ///////////
    // Hooks //
    ///////////

    function init() internal override returns (bool) {
        balancerPool = IBalancerPool(vAmmInfo.poolAddress);

        return true;
    }

    function checkPoolExists() internal override returns (bool) {
        try balancerVault.getPool(vAmmInfo.poolId) {
            return true;
        } catch {
            return false;
        }
    }

    function deployPool() internal override returns (address) {
        //Check that pool data is set with above function

        // Approve Balancer vault to spend tokens
        for (uint256 i; i < newPoolData.tokens.length; i++) {
            IERC20(newPoolData.tokens[i]).approve(address(balancerVault), type(uint256).max);
        }

        IERC20[] memory tokens = new IERC20[](newPoolData.tokens.length);
        for (uint256 i; i < newPoolData.tokens.length; i++) {
            tokens[i] = IERC20(newPoolData.tokens[i]);
        }

        return
            weightedPoolFactory.create(
                string(abi.encodePacked("aevAMM-", newPoolData.name)),
                string(abi.encodePacked("aevA-", newPoolData.symbol)),
                tokens,
                newPoolData.weights,
                newPoolData.rateProviders,
                newPoolData.swapFeePercentage,
                msg.sender,
                bytes32(0) // TODO investigate what to do with this SALT
            );
    }

    function addInitialLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(true);
    }

    function addLiquidity() internal override returns (uint256, uint256, uint256, uint256) {
        return _addLiquidity(false);
    }

    function _addLiquidity(bool _initialLiquidity) internal returns (uint256, uint256, uint256, uint256) {
        AddLiquidity memory _addLiquidityData = createAddLiquidity();

        /// @dev don't we already have this in the vestAMM info?
        bytes32 poolId = IBalancerPool(_addLiquidityData.poolAddress).getPoolId();

        // Some pools can change which tokens they hold so we need to tell the Vault what we expect to be adding.
        // This prevents us from thinking we're adding 100 DAI but end up adding 100 BTC!
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);

        // NOTE: Since this contract is not an approved relayer (https://github.com/balancer/balancer-v2-monorepo/blob/e3fb9a51e5d66ed7bdcf97ddfd5eced1ee40f8fe/pkg/interfaces/contracts/vault/IVault.sol#L348)
        // We need to pull the tokens from the sender into this contract before we can add liquidity.
        // TODO: check possible attack vectors
        for (uint256 i; i < tokens.length; i++) {
            tokens[i].transferFrom(msg.sender, address(this), _addLiquidityData.tokensAmtsIn[i]);
        }

        IAsset[] memory assets = _convertERC20sToAssets(tokens);

        // These are the slippage limits preventing us from adding more tokens than we expected.
        // If the pool trys to take more tokens than we've allowed it to then the transaction will revert.
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max; // QUESTION We don't want to limit the amount of tokens we can add ???
        }

        //NOTE: This is the maximum amount of BPT we want to receive. We set it to the max value so we can receive as much as possible
        uint256 maxBpTAmountOut = type(uint256).max;

        WeightedPoolUserData.JoinKind joinKind = WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;

        if (_initialLiquidity) {
            joinKind = WeightedPoolUserData.JoinKind.INIT;
        }

        bytes memory userData = abi.encode(
            joinKind,
            _addLiquidityData.tokensAmtsIn,
            _initialLiquidity ? maxBpTAmountOut : 0
        );

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        // Here we're using tokens held on this contract to provide liquidity and also revceive the BPT tokens
        // This means that the caller of this function will be won't the owner of the BPT
        // address sender = address(this);
        // address recipient = msg.sender; => vestAMM
        balancerVault.joinPool(poolId, address(this), msg.sender, request);

        // TODO: should return (numInvTokensInLP, numBaseTokensInLP, numInvTokensFee, numBaseTokensFee)
        return (_addLiquidityData.tokensAmtsIn[0], _addLiquidityData.tokensAmtsIn[1], 0, 0);
    }

    function removeLiquidity(uint256 _tokensAmtsIn) internal override returns (uint256, uint256) {
        RemoveLiquidity memory _removeLiquidityData = createRemoveLiquidity(_tokensAmtsIn);

        bytes32 poolId = IBalancerPool(_removeLiquidityData.poolAddress).getPoolId();

        // First approve Vault to use vAMM LP tokens
        /// @dev token approvals maybe better in init() so that this isn't called each time
        (address poolAddress, ) = balancerVault.getPool(poolId);
        IERC20(poolAddress).approve(address(balancerVault), _removeLiquidityData.lpTokenAmtIn);

        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);

        // Here we're giving the minimum amounts of each token we'll accept as an output
        // For simplicity we're setting this to all zeros
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        // We can ask the Vault to keep the tokens we receive in our internal balance to save gas
        bool toInternalBalance = false;

        bytes memory userData = abi.encode(
            WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
            _removeLiquidityData.lpTokenAmtIn
        );

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            minAmountsOut: minAmountsOut,
            userData: userData,
            toInternalBalance: toInternalBalance
        });

        IERC20(_removeLiquidityData.lpToken).transferFrom(msg.sender, address(this), _removeLiquidityData.lpTokenAmtIn);

        address sender = address(this);
        address payable recipient = payable(msg.sender);

        uint256 token0AmtBefore = IERC20(_removeLiquidityData.tokens[0]).balanceOf(msg.sender);
        uint256 token1AmtBefore = IERC20(_removeLiquidityData.tokens[1]).balanceOf(msg.sender);

        balancerVault.exitPool(poolId, sender, recipient, request);

        uint256 token0AmtAfter = IERC20(_removeLiquidityData.tokens[0]).balanceOf(msg.sender);
        uint256 token1AmtAfter = IERC20(_removeLiquidityData.tokens[1]).balanceOf(msg.sender);

        return (token0AmtAfter - token0AmtBefore, token1AmtAfter - token1AmtBefore);
    }

    /////////////
    // Helpers //
    /////////////

    function _convertERC20sToAssets(IERC20[] memory _tokens) internal pure returns (IAsset[] memory assets) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            assets := _tokens
        }
    }

    function createAddLiquidity() internal view returns (AddLiquidity memory) {
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

        return RemoveLiquidity(address(balancerPool), address(balancerPool), _tokensAmtsIn, tokens);
    }
}
