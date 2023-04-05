// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "forge-std/console.sol";

import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/VestAMM/interfaces/balancer/IWeightedPoolFactory.sol";
import "contracts/VestAMM/interfaces/balancer/IVault.sol";
import "contracts/VestAMM/interfaces/balancer/IBalancerPool.sol";
import "contracts/VestAMM/interfaces/balancer/IAsset.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";

contract BalancerVestAMM {
    IWeightedPoolFactory internal immutable weightedPoolFactory;
    IVault internal immutable balancerVault;

    address vaultAddress = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address weightedPoolFactoryAddress = address(0x5Dd94Da3644DDD055fcf6B3E1aa310Bb7801EB8b);

    constructor() {
        balancerVault = IVault(vaultAddress);
        weightedPoolFactory = IWeightedPoolFactory(weightedPoolFactoryAddress);
    }

    // NOTE: This function will be called frop VestAMM contract to create a new
    // balancer pool and add liquidity to it for the first time
    function deployPool(IVestAMMLibrary.DeployPool calldata _deployPool) public returns (address) {
        IBalancerPool.CreateNewPool memory newPoolParsed = _parseNewPoolParams(_deployPool);

        return _createPool(newPoolParsed);
    }

    function _createPool(IBalancerPool.CreateNewPool memory _newPool) internal returns (address) {
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

    function _parseNewPoolParams(IVestAMMLibrary.DeployPool calldata _deployPool)
        internal
        pure
        returns (IBalancerPool.DeployPool memory)
    {
        return
            IBalancerPool.CreateNewPool({
                name: _deployPool.name,
                symbol: _deployPool.symbol,
                tokens: _deployPool.tokens,
                weights: _deployPool.normalizedWeights,
                rateProviders: _deployPool.rateProviders,
                swapFeePercentage: _deployPool.swapFeePercentage
            });
    }

    function addInitialLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (uint256, uint256)
    {
        _addLiquidity(_addLiquidityData.poolAddress, _addLiquidityData.tokensAmtsIn, true);
    }

    function addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData) external returns (uint256, uint256) {
        _addLiquidity(_addLiquidityData.poolAddress, _addLiquidityData.tokensAmtsIn, false);
    }

    function _addLiquidity(
        address _poolAddress,
        uint256[] calldata _tokensAmtsIn,
        bool _initialLiquidity
    ) internal {
        bytes32 poolId = IBalancerPool(_poolAddress).getPoolId();

        // Some pools can change which tokens they hold so we need to tell the Vault what we expect to be adding.
        // This prevents us from thinking we're adding 100 DAI but end up adding 100 BTC!
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);

        // NOTE: Since this contract is not an approved relayer (https://github.com/balancer/balancer-v2-monorepo/blob/e3fb9a51e5d66ed7bdcf97ddfd5eced1ee40f8fe/pkg/interfaces/contracts/vault/IVault.sol#L348)
        // We need to pull the tokens from the sender into this contract before we can add liquidity.
        // TODO: check possible attack vectors
        for (uint256 i; i < tokens.length; i++) {
            tokens[i].transferFrom(msg.sender, address(this), _tokensAmtsIn[i]);
        }

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

        //NOTE: This is the maximum amount of BPT we want to receive. We set it to the max value so we can receive as much as possible
        uint256 maxBpTAmountOut = type(uint256).max;

        // NOTE: When adding liquidity for the second time we need to specify the minimum amount of BPT we want to receive
        uint256 minBpTAmtOut = 0;

        WeightedPoolUserData.JoinKind joinKind = WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;

        if (_initialLiquidity) {
            joinKind = WeightedPoolUserData.JoinKind.INIT;
        }

        bytes memory userData = abi.encode(joinKind, _tokensAmtsIn, _initialLiquidity ? maxBpTAmountOut : minBpTAmtOut);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: fromInternalBalance
        });

        // Here we're using tokens held on this contract to provide liquidity and also revceive the BPT tokens
        // This means that the caller of this function will be won't the owner of the BPT
        address sender = address(this);
        address recipient = address(this);

        balancerVault.joinPool(poolId, sender, recipient, request);
    }

    function removeLiquidity(IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData) external {
        bytes32 poolId = IBalancerPool(_removeLiquidityData.poolAddress).getPoolId();

        // First approve Vault to use vAMM LP tokens
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

        address sender = address(this);
        address payable recipient = payable(msg.sender);
        balancerVault.exitPool(poolId, sender, recipient, request);
    }

    function checkPoolExists(bytes32 _poolId) external view returns (bool) {
        try balancerVault.getPool(_poolId) {
            return true;
        } catch {
            return false;
        }
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
