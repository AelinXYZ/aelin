// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";

import "../interfaces/IVestAMMLibrary.sol";
import WeightedPool from '@balancer-labs/v2-helpers/src/models/pools/weighted/WeightedPool';

library BalancerVestAMM is IVestAMMLibrary, BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(WeightedPool).creationCode) {
    }
    function deployPool(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner
    ) external {
        WeightedPool.create(
            name,
            symbol,
            tokens,
            normalizedWeights,
            rateProviders,
            swapFeePercentage,
            owner
        );
        // TODO implement a single pool creation and add liquidity
    }

    function addLiquidity() external {
        expected = pool.calc_token_amount([1e18, 1e18], true) * 0.99

        pool.add_liquidity([1e18, 1e18], expected, {'from': alice})
    }

    function removeLiquidity() external {
        // ...
    }

}