// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/balancer/IWeightedPoolFactory.sol";
import {IVault} from "contracts/interfaces/balancer/IVault.sol";
import {IBalancerPool} from "contracts/interfaces/balancer/IBalancerPool.sol";
import {IAsset} from "contracts/interfaces/balancer/IAsset.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalancerVestAMM {
    IWeightedPoolFactory internal immutable weightedPoolFactory;
    IVault internal immutable balancerVault;

    address vaultAddress = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address weightedPoolFactoryAddress = address(0x5Dd94Da3644DDD055fcf6B3E1aa310Bb7801EB8b);

    constructor() {
        balancerVault = IVault(vaultAddress);
        weightedPoolFactory = IWeightedPoolFactory(weightedPoolFactoryAddress);
    }

    function createPool(IBalancerPool.CreateNewPool calldata _newPool) public returns (address) {
        // Approve Balancer vault to spend tokens
        for (uint256 i; i < _newPool.tokens.length; i++) {
            _newPool.tokens[i].approve(address(balancerVault), type(uint256).max);
        }

        return
            weightedPoolFactory.create(
                string(abi.encodePacked("aevAMM-", _newPool.name)),
                string(abi.encodePacked("aevA-", _newPool.symbol)),
                _newPool.tokens,
                _newPool.weights,
                _newPool.rateProviders,
                _newPool.swapFeePercentage,
                address(this) // owner the protocol? or vAMM ?
            );
    }

    function deployPool(IBalancerPool.CreateNewPool calldata _newPool, bytes memory _userData) public {
        address poolAddress = createPool(_newPool);
        bytes32 poolId = IBalancerPool(poolAddress).getPoolId();
        addLiquidity(poolId, _userData);
    }

    /**
     * This function demonstrates how to initialize a pool as the first liquidity provider
     * So the pool already exists and we're just adding the initial liquidity
     */
    function addLiquidity(bytes32 _poolId, bytes memory _userData) public {
        // Some pools can change which tokens they hold so we need to tell the Vault what we expect to be adding.
        // This prevents us from thinking we're adding 100 DAI but end up adding 100 BTC!
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(_poolId);

        IAsset[] memory assets = _convertERC20sToAssets(tokens);

        // These are the slippage limits preventing us from adding more tokens than we expected.
        // If the pool trys to take more tokens than we've allowed it to then the transaction will revert.
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max; // QUESTION We don't want to limit the amount of tokens we can add ???
        }

        // We can ask the Vault to use the tokens which we already have on the vault before using those on our address
        // If we set this to false, the Vault will always pull all the tokens from our address.
        // QUESTION How is possible that the vault kept/has tokens?
        // ANSWER => When exiting a pool, there's possibility to KEEP tokens inside the vault.
        // In this case, then there will be balance in the vault
        bool fromInternalBalance = false;

        // We need to create a JoinPoolRequest to tell the pool how we we want to add liquidity
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: _userData,
            fromInternalBalance: fromInternalBalance
        });

        // We can tell the vault where to take tokens from and where to send BPT to
        // If you don't have permission to take the sender's tokens then the transaction will revert.
        // Here we're using tokens held on this contract to provide liquidity and forward the BPT to msg.sender.
        // This means that the caller of this function will be the owner of the BPT (vAMM)
        address sender = address(this);
        address recipient = address(this); //msg.sender;

        balancerVault.joinPool(_poolId, sender, recipient, request);
    }

    /**
     * This function demonstrates how to remove liquidity from a pool
     */
    function removeLiquidity(
        bytes32 _poolId,
        bytes memory _userData,
        uint256 _bptAmountIn
    ) public {
        // First approve Vault to use vAMM LP tokens
        (address poolAddress, ) = balancerVault.getPool(_poolId);
        IERC20(poolAddress).approve(address(balancerVault), _bptAmountIn);

        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(_poolId);

        // Here we're giving the minimum amounts of each token we'll accept as an output
        // For simplicity we're setting this to all zeros
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        // We can ask the Vault to keep the tokens we receive in our internal balance to save gas
        bool toInternalBalance = false;

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            minAmountsOut: minAmountsOut,
            userData: _userData,
            toInternalBalance: toInternalBalance
        });

        address sender = address(this);
        address payable recipient = payable(msg.sender);
        balancerVault.exitPool(_poolId, sender, recipient, request);
    }

    /**
     * @dev This helper function is a fast and cheap way to convert between IERC20[] and IAsset[] types
     */
    function _convertERC20sToAssets(IERC20[] memory _tokens) internal pure returns (IAsset[] memory assets) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            assets := _tokens
        }
    }
}
