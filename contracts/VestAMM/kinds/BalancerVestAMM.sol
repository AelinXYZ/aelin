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

contract BalancerVestAMM is VestAMM {
    /// @dev check hardcoding here???
    IWeightedPoolFactory internal constant weightedPoolFactory =
        IWeightedPoolFactory(address(0x897888115Ada5773E02aA29F775430BFB5F34c51));
    IVault internal constant balancerVault = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

    ///////////
    // Hooks //
    ///////////

    function init() internal override returns (bool) {}

    function checkPoolExists() internal override returns (bool) {
        try balancerVault.getPool(vAmmInfo.poolId) {
            return true;
        } catch {
            return false;
        }
    }

    function deployPool() internal override returns (address) {}

    //function addLiquidity() internal override returns (uint256, uint256, uint256, uint256) {}

    //function addInitialLiquidity() internal override returns (uint256, uint256, uint256, uint256) {}

    //function removeLiquidity(uint256 _tokensAmtsIn) internal override returns (uint256, uint256) {}

    /////////////
    // Helpers //
    /////////////

    /*
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

        return RemoveLiquidity(address(sushiPool), address(sushiPool), _tokensAmtsIn, tokens);
    }
    */
}
