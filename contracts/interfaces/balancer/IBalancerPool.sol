// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

interface IBalancerPool {
    struct CreateNewPool {
        string name;
        string symbol;
        IERC20[] tokens;
        uint256[] weights;
        // TODO Investigate what this is for and if we need it (leave if as optional/arg)
        // https://docs.balancer.fi/reference/contracts/rate-providers.html
        IRateProvider[] rateProviders;
        uint256 swapFeePercentage;
    }

    struct AddLiquidity {
        bytes32 _poolId;
        bytes _userData;
    }

    function getPoolId() external view returns (bytes32);

    function getActualSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}
