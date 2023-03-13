// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IVestAMMLibrary.sol";
// TODO import the IWeightedPoolFactory interface

library BalancerVestAMM is IVestAMMLibrary, BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    IWeightedPoolFactory immutable weightedPoolFactory;

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
        balancerPool = weightedPoolFactory.create(
            // name,
            // symbol,
            // tokens,
            // normalizedWeights,
            // 0.04e16,
            // address(this)
        );
        // TODO implement adding liquidity after pool creation if you can't do it when creating the pool itself
        addLiquidity()
    }

    function addLiquidity() external {
        expected = pool.calc_token_amount([1e18, 1e18], true) * 0.99

        pool.add_liquidity([1e18, 1e18], expected, {'from': alice})
    }

    function removeLiquidity() external {
        // ...
    }

}