// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IVestAMMLibrary.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

// TODO import the IWeightedPoolFactory interface

library BalancerVestAMM is IVestAMMLibrary {
    IWeightedPoolFactory immutable weightedPoolFactory;
    address public vault;
    bytes32 public poolId;

    constructor(address _weightedPoolFactory) {
        weightedPoolFactory = IWeightedPoolFactory(_weightedPoolFactory);
    }

    // NOTE that we need to create a single set of arguments from a single struct that
    // will work for creating and deploying a pool on any AMM. If we need to create
    // a second struct for this we can do that as well
    function deployPool(
        // name of the pool
        string memory name,
        // symbol of the pool
        string memory symbol,
        // NOTE these are the 2 tokens we are using
        IERC20[] memory tokens,
        // this is where you put the ratio between the 2 tokens
        uint256[] memory normalizedWeights,
        // not sure what this is
        IRateProvider[] memory rateProviders,
        // this is the fees for trading. probably 1% but TBD
        uint256 swapFeePercentage,
        // this is the LP owner which is the vAMM contract
        address owner
    ) external {
        // TODO make sure we are calling the latest pool factory with the right arguments
        // TODO save the vault here
        // save the pool id
        balancerPool = weightedPoolFactory.create();
        poolId = balancerPool.id;
        // name,
        // symbol,
        // tokens,
        // normalizedWeights,
        // 0.04e16,
        // address(this)
        // TODO implement adding liquidity after pool creation if you can't do it when creating the pool itself
        addLiquidity();
    }

    /// @notice add liquidity to a v2 weighted pool
    /// @dev Calls into AMM contract
    /// @param tokens ERC20 tokens to be added as liquidity to pool
    /// @param amounts amount of tokens to add to the pool
    /// @param poolAmountOut number of LP tokens received from the pool
    function addLiquidity(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256 poolAmountOut
    ) external {
        // TODO add modifiers here to restrict access
        uint256 numTokens = tokens.length;
        require(numTokens == amounts.length, "TOKEN_AMOUNTS_COUNT_MISMATCH");
        require(numTokens > 0, "!TOKENS");
        require(poolAmountOut > 0, "!POOL_AMOUNT_OUT");

        // get bpt address of the pool (for later balance checks)
        (address poolAddress, ) = vault.getPool(poolId);

        // verify that we're passing correct pool tokens
        // (two part verification: total number checked here, and individual match check below)
        (IERC20[] memory poolAssets, , ) = vault.getPoolTokens(poolId);
        require(poolAssets.length == numTokens, "numTokens != numPoolTokens");

        uint256[] memory assetBalancesBefore = new uint256[](numTokens);

        // run through tokens and make sure we have approvals (and correct token order)
        for (uint256 i = 0; i < numTokens; ++i) {
            // as per new requirements, 0 amounts are not allowed even though balancer supports it
            require(amounts[i] > 0, "!AMOUNTS[i]");

            require(tokens[i] == poolAssets[i], "tokens[i]!=poolAssets[i]");

            // record previous balance for this asset
            // NOTE it might not be address(this) here. TBD
            assetBalancesBefore[i] = tokens[i].balanceOf(address(this));

            // grant spending approval to balancer's Vault
            _approve(tokens[i], amounts[i]);
        }

        // record balances before deposit
        // NOTE again it might not be address(this) here
        uint256 bptBalanceBefore = IERC20(poolAddress).balanceOf(address(this));

        // encode pool entrance custom userData
        bytes memory userData = abi.encode(
            WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
            amounts, //maxAmountsIn,
            poolAmountOut
        );

        IVault.JoinPoolRequest memory joinRequest = IVault.JoinPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            maxAmountsIn: amounts, // maxAmountsIn,
            userData: userData,
            fromInternalBalance: false // vault will pull the tokens from contoller instead of internal balances
        });

        vault.joinPool(
            poolId,
            address(this), // sender
            address(this), // recipient of BPT token
            joinRequest
        );

        // make sure we received bpt
        uint256 bptBalanceAfter = IERC20(poolAddress).balanceOf(address(this));
        require(bptBalanceAfter >= bptBalanceBefore.add(poolAmountOut), "BPT_MUST_INCREASE_BY_MIN_POOLAMOUNTOUT");
        // NOTE we probably want to record bptBalancerAfter
        // at the end and maybe return this value for tracking
        // make sure assets were taken out
        for (uint256 i = 0; i < numTokens; ++i) {
            require(tokens[i].balanceOf(address(this)) == assetBalancesBefore[i].sub(amounts[i]), "ASSET_MUST_DECREASE");
        }
    }

    /// @notice Withdraw liquidity from Balancer V2 pool (specifying exact asset token amounts to get)
    /// @dev Calls into AMM contract
    /// @param maxBurnAmount Max amount of LP tokens to burn in the withdrawal
    /// @param exactAmountsOut Array of exact amounts of tokens to be withdrawn from pool
    function removeLiquidity(
        uint256 maxBurnAmount,
        IERC20[] calldata tokens,
        uint256[] calldata exactAmountsOut
    ) external {
        // TODO add modifiers here to restrict access
        // encode withdraw request
        bytes memory userData = abi.encode(
            WeightedPoolUserData.ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT,
            exactAmountsOut,
            maxBurnAmount
        );

        _withdraw(poolId, maxBurnAmount, tokens, exactAmountsOut, userData);
    }

    // TODO figure out which withdraw methods we need to use
    /// @notice Withdraw liquidity from Balancer V2 pool (specifying exact LP tokens to burn)
    /// @dev Calls into AMM contract
    /// @param poolAmountIn Amount of LP tokens to burn in the withdrawal
    /// @param minAmountsOut Array of minimum amounts of tokens to be withdrawn from pool
    function removeLiquidityImbalance(
        uint256 poolAmountIn,
        IERC20[] calldata tokens,
        uint256[] calldata minAmountsOut
    ) external {
        // TODO add modifiers to restrict access
        // encode withdraw request
        bytes memory userData = abi.encode(WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, poolAmountIn);

        _withdraw(poolId, poolAmountIn, tokens, minAmountsOut, userData);
    }

    function _withdraw(
        uint256 bptAmount,
        IERC20[] calldata tokens,
        uint256[] calldata amountsOut,
        bytes memory userData
    ) internal {
        uint256 nTokens = tokens.length;
        require(nTokens == amountsOut.length, "IN_TOKEN_AMOUNTS_COUNT_MISMATCH");
        require(nTokens > 0, "!TOKENS");

        (IERC20[] memory poolTokens, , ) = vault.getPoolTokens(poolId);
        uint256 numTokens = poolTokens.length;
        require(numTokens == amountsOut.length, "TOKEN_AMOUNTS_LENGTH_MISMATCH");

        // run through tokens and make sure it matches the pool's assets
        for (uint256 i = 0; i < nTokens; ++i) {
            require(tokens[i] == poolTokens[i], "tokens[i] != poolTokens[i]");
        }

        // grant erc20 approval for vault to spend our tokens
        (address poolAddress, ) = vault.getPool(poolId);
        _approve(IERC20(poolAddress), bptAmount);

        // record balance before withdraw
        // NOTE again might not be address(this)
        uint256 bptBalanceBefore = IERC20(poolAddress).balanceOf(address(this));
        uint256[] memory assetBalancesBefore = new uint256[](poolTokens.length);
        for (uint256 i = 0; i < numTokens; ++i) {
            assetBalancesBefore[i] = poolTokens[i].balanceOf(address(this));
        }

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(poolTokens),
            minAmountsOut: amountsOut,
            userData: userData,
            toInternalBalance: false // send tokens back to us vs keeping inside vault for later use
        });

        vault.exitPool(
            poolId,
            address(this), // sender,
            payable(address(this)), // recipient,
            request
        );

        // make sure we burned bpt, and assets were received
        require(IERC20(poolAddress).balanceOf(address(this)) < bptBalanceBefore, "BPT_MUST_DECREASE");
        for (uint256 i = 0; i < numTokens; ++i) {
            require(
                poolTokens[i].balanceOf(address(this)) >= assetBalancesBefore[i].add(amountsOut[i]),
                "ASSET_MUST_INCREASE"
            );
        }
    }

    /// @dev Make sure vault has our approval for given token (reset prev approval)
    function _approve(IERC20 token, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), address(vault));
        if (currentAllowance > 0) {
            token.safeDecreaseAllowance(address(vault), currentAllowance);
        }
        token.safeIncreaseAllowance(address(vault), amount);
    }

    /**
     * @dev This helper function is a fast and cheap way to convert between IERC20[] and IAsset[] types
     */
    function _convertERC20sToAssets(IERC20[] memory tokens) internal pure returns (IAsset[] memory assets) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            assets := tokens
        }
    }
}
