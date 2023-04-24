// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWeightedPoolFactory {
    struct CreatePoolParams {
        string name;
        string symbol;
        IERC20[] tokens;
        uint256[] normalizedWeights;
        IRateProvider[] rateProviders;
        uint256 swapFeePercentage;
        address owner;
        bytes32 salt;
    }

    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner
    ) external returns (address);
}
