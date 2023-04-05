// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

// import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {WeightedPoolUserData} from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

// interface IERC20 {
//     function decimals() external view returns (uint8);

//     function name() external view returns (string memory);
// }

interface IAsset {

}

interface IProtocolFeesCollector {
    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external;

    function getCollectedFeeAmounts(IERC20[] memory tokens) external view returns (uint256[] memory feeAmounts);
}

interface IVault {
    enum PoolSpecialization {
        GENERAL,
        MINIMAL_SWAP_INFO,
        TWO_TOKEN
    }

    function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);

    function getInternalBalance(address user, IERC20[] memory tokens) external view returns (uint256[] memory);

    function getPoolTokenInfo(bytes32 poolId, IERC20 token)
        external
        view
        returns (
            uint256 cash,
            uint256 managed,
            uint256 lastChangeBlock,
            address assetManager
        );

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external;

    struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }
}

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

contract BalancerVestAMM {
    IWeightedPoolFactory internal immutable weightedPoolFactory;
    IVault internal immutable balancerVault;
    bytes32 public poolId;
    IERC20[] _tokens = new IERC20[](2);

    IERC20 Dai = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    IERC20 Aelin = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));

    constructor(address _vault, address _weightedPoolFactory) {
        balancerVault = IVault(_vault);
        weightedPoolFactory = IWeightedPoolFactory(_weightedPoolFactory);
    }

    // Args needed:
    // tokens: IERC20[]
    // weights: uint256[]
    // rateProviders: IRateProvider[] ???
    // swapFeePercentage: uint256
    function createPool() external returns (address) {
        // IERC20[] memory tokens = new IERC20[](2);
        _tokens[0] = Dai;
        _tokens[1] = Aelin;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 500000000000000000; // 50%
        weights[1] = 500000000000000000; // 50%

        // TODO Investigate what this is for and if we need it (leave if as optional/arg)
        // https://docs.balancer.fi/reference/contracts/rate-providers.html
        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));

        // Approve Balancer vault to spend tokens
        for (uint256 i; i < _tokens.length; i++) {
            _tokens[i].approve(address(balancerVault), type(uint256).max);
        }

        return
            weightedPoolFactory.create(
                "Linuz Test Balancer 50Dai-50Aelin",
                "50Dai-50Aelin",
                _tokens, //_poolData.tokens,
                weights, //50% - 50% //_poolData.normalizedWeights,
                //_poolData.rateProviders,
                rateProviders,
                2500000000000000, //_poolData.swapFeePercentage, 2,5%
                address(this) // owner is the protocol? or vAMM ?
            );
    }

    /**
     * This function demonstrates how to initialize a pool as the first liquidity provider
     * So the pool already exists and we're just adding the initial liquidity
     */
    function addLiquidity(bytes32 _poolId, bytes memory userData) public {
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
            userData: userData,
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
        bytes32 poolId,
        bytes memory userData,
        uint256 bptAmountIn
    ) public {
        // First approve Vault to use vAMM LP tokens
        (address poolAddress, ) = balancerVault.getPool(poolId);
        IERC20(poolAddress).approve(address(balancerVault), bptAmountIn);

        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);

        // Here we're giving the minimum amounts of each token we'll accept as an output
        // For simplicity we're setting this to all zeros
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        // We can ask the Vault to keep the tokens we receive in our internal balance to save gas
        bool toInternalBalance = false;

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

    function getCollectedFeeAmounts(bytes32 poolId) external view returns (uint256[] memory feeAmounts) {
        (IERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);
        IProtocolFeesCollector feesCollector = balancerVault.getProtocolFeesCollector();
        return feesCollector.getCollectedFeeAmounts(tokens);
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
