// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../interfaces/IVestAMMLibrary.sol";
import WeightedPool from '@balancer-labs/v2-helpers/src/models/pools/weighted/WeightedPool';

library BalancerVestAMM is IVestAMMLibrary {
    function deployPool() external {
        tokens = allTokens.subset(2);

      pool = await WeightedPool.create({
        poolType: WeightedPoolType.WEIGHTED_POOL,
        tokens,
        weights: WEIGHTS.slice(0, 2),
        swapFeePercentage: POOL_SWAP_FEE_PERCENTAGE,
      });

      await pool.init({ initialBalances, recipient: lp });
    }

    function addLiquidity() external {
        expected = pool.calc_token_amount([1e18, 1e18], true) * 0.99

        pool.add_liquidity([1e18, 1e18], expected, {'from': alice})
    }

    function removeLiquidity() external {
        // ...
    }

}