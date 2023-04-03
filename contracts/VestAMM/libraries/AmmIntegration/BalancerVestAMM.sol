// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "../../interfaces/IVestAMMLibrary.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./IBalancerPool.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

// TODO if Balancer offers additional rewards to locked LPs outside of the trading fees
// first, they can do those rewards directly using single sided rewards via our contracts instead
// but let's say that if you own any balancer LP tokens you are eligible for rewards separate from VestAMM
// what we can do is take those rewards here in this contract somewhere and claim them for LPs in the pool as well
// or we just give the extra fees to AELIN Fee Module
library BalancerVestAMM is IVestAMMLibrary {
    IWeightedPoolFactory immutable weightedPoolFactory;
    address public vault;
    bytes32 public poolId;

    constructor(address _weightedPoolFactory) {
        weightedPoolFactory = IWeightedPoolFactory(_weightedPoolFactory);
    }

    struct DeployPoolBalancer {
        uint256 testNum;
    }

    struct AddLiquidityBalancer {
        uint256 testNum;
    }

    function parseDeployPoolArgs(CreateNewPool _createPool) internal {
        // get each field you need
        // return the fields you need
    }

    function parseAddLiquidityArgs(AddLiquidity _addLiquidity) internal {
        // get each field you need
        // return the fields you need
    }

    // 0. deployPool (with the right assets & weightings) only when its a new liquidity launch
    // 1. add liquidity. for every pool (5M ABC, 1M sUSD) (1M ABC, 1M sUSD) (5M ABC, 500K sUSD)
    // - check the ratio of assets in the pool
    // - deposit according to the ratio
    // - track the amount of LP tokens that we receive
    // 2. remove liquidity
    // - pass in the number of LP tokens to remove based on the users ownership of the LP tokens + the users vesting schedule
    // - determine how many LP tokens were removed and track accordingly
    // 3. fee calculation view + the ability to capture fees from LP tokens
    // - imagine we have 5M ABC/ 1M sUSD locked for 6 months. this yields 20% in swap fees
    // - calculate the amount of swap fees earned. Send 20% to the AelinFeeModule
    // - not for Balancer: if the fees are not reinvested into the LP tokens, write a method to reinvest them

    function deployPool(
        address tokenA,
        address tokenB,
        uint256 ratioA,
        uint256 ratioB,
        uint256 swapFeePercentage
    ) external returns (address) {
        // Check if the tokens and ratios are valid
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");
        require(ratioA > 0 && ratioB > 0, "Invalid token ratios");

        // Prepare pool creation data
        bytes memory poolCreationData = abi.encode(tokenA, tokenB, ratioA, ratioB, swapFeePercentage);

        // Create the new weighted pool
        address newPoolAddress = balancerPoolFactory.create("WeightedBalancerPool", balancerVault, poolCreationData);

        // Return the new pool address
        return newPoolAddress;
    }

    // the protocol gives us 100K ABC
    // investors give us the full cap of 500K sUSD or a lower amount e.g. 253K sUSD
    function addLiquidity(
        address tokenA, // ABC
        address tokenB, // sUSD
        uint256 amountA, // 100000 * 1e18
        uint256 amountB, // 253000 * 1e6 or up to 500000 * 1e6 if we hit the cap
        address balancerPoolAddress
    )
        external
        returns (
            uint256 lpTokens,
            uint256 finalAmountA,
            uint256 finalAmountB
        )
    {
        // Check if the Balancer pool address is valid
        require(balancerPoolAddress != address(0), "Invalid Balancer pool address");

        // Instances of the ERC20 tokens and Balancer pool
        IERC20 erc20A = IERC20(tokenA);
        IERC20 erc20B = IERC20(tokenB);
        IBalancerPool balancerPool = IBalancerPool(balancerPoolAddress);

        // Approve the Balancer pool to spend tokens on behalf of the sender
        erc20A.approve(balancerPoolAddress, amountA);
        erc20B.approve(balancerPoolAddress, amountB);

        // Get the current balance of the sender's LP tokens
        uint256 initialLpBalance = balancerPool.balanceOf(address(this));

        // Calculate the maximum amount of token A that can be added based on the desired token B amount
        uint256 maxAmountA = balancerPool.calcTokenAForB(amountB, tokenA, tokenB);

        // Calculate the maximum amount of token B that can be added based on the desired token A amount
        uint256 maxAmountB = balancerPool.calcTokenBForA(amountA, tokenA, tokenB);

        // Calculate the actual amounts of tokens A and B to be added
        finalAmountA = amountA <= maxAmountA ? amountA : maxAmountA;
        finalAmountB = amountB <= maxAmountB ? amountB : maxAmountB;

        // Add liquidity to the Balancer pool
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 0;
        minAmountsOut[1] = 0;
        address[] memory tokens = new address[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = finalAmountA;
        amounts[1] = finalAmountB;
        // join as this contract and not the msg.sender
        balancerPool.joinPool(amounts, minAmountsOut);

        // Get the balance of the sender's LP tokens after providing liquidity
        uint256 finalLpBalance = balancerPool.balanceOf(address(this));

        // Calculate the number of LP tokens received
        lpTokens = finalLpBalance - initialLpBalance;

        // Return LP tokens, final amount of token A, and final amount of token B
        // TODO if ABC token goes up in price and we have some left then we are going
        // to put that on a single sided rewards on the same vesting schedule
        return (lpTokens, finalAmountA, finalAmountB);
    }

    //     pragma solidity ^0.8.0;

    // import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    // import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    // import "./interfaces/IVault.sol";
    // import "./interfaces/IWeightedPool.sol";

    // contract BalancerLiquidityRemover {
    //     using SafeMath for uint256;

    //     IVault public balancerVault;

    //     constructor(address _balancerVault) {
    //         balancerVault = IVault(_balancerVault);
    //     }

    function removeFixedPercentLiquidity(address poolAddress, uint256 percent) external {
        require(percent > 0 && percent <= 100, "Invalid percentage");

        IWeightedPool balancerPool = IWeightedPool(poolAddress);

        // Calculate the amount of LP tokens to remove based on the percentage
        uint256 lpTokenBalance = balancerPool.balanceOf(msg.sender);
        uint256 lpTokensToRemove = lpTokenBalance.mul(percent).div(100);

        // Approve the Balancer pool to burn the LP tokens
        balancerPool.approve(poolAddress, lpTokensToRemove);

        // Get the pool tokens
        (address[] memory tokens, , ) = balancerVault.getPoolTokens(poolAddress);
        uint256 numTokens = tokens.length;

        // Set the minimum amounts of tokens to be received when removing liquidity
        uint256[] memory minAmountsOut = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            minAmountsOut[i] = 0;
        }

        // Remove the liquidity from the Balancer pool
        balancerPool.exitPool(lpTokensToRemove, minAmountsOut);
    }

    // import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    // import "@openzeppelin/contracts/utils/math/Math.sol";
    // import "./interfaces/IVault.sol";
    // import "./interfaces/IWeightedPool.sol";
    // contract BalancerFeesCalculator {
    // IVault public balancerVault;

    // constructor(address _balancerVault) {
    //     balancerVault = IVault(_balancerVault);
    // }

    function calculateFeesEarned(address poolAddress, address lpAddress)
        external
        view
        returns (uint256[] memory feesEarned)
    {
        IWeightedPool balancerPool = IWeightedPool(poolAddress);

        // Get the pool tokens and their balances
        (address[] memory tokens, , ) = balancerVault.getPoolTokens(poolAddress);

        uint256 numTokens = tokens.length;
        feesEarned = new uint256[](numTokens);

        // Calculate the total swap fees in the pool
        uint256 totalFees = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenFees = balancerPool.getSwapFeeAmount(tokens[i]);
            totalFees = Math.add(totalFees, tokenFees);
        }

        // Calculate the LP's share of the fees
        uint256 lpBalance = balancerPool.balanceOf(lpAddress);
        uint256 totalSupply = balancerPool.totalSupply();

        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenFees = balancerPool.getSwapFeeAmount(tokens[i]);
            uint256 lpTokenFees = Math.mulDiv(tokenFees, lpBalance, totalSupply);
            feesEarned[i] = lpTokenFees;
        }
    }

    // using SafeMath for uint256;

    // IVault public balancerVault;

    // constructor(address _balancerVault) {
    //     balancerVault = IVault(_balancerVault);
    // }

    // TODO we need to determine how many swap fees have been generated by all the
    // balancer or whatever AMM LP tokens that we have in our control and we want to
    // take 20% of the swap fees for AELIN protocol fees. the rest of the swap fees
    // we want to auto reinvest for users in the LP tokens held by this contract
    // NOTE that balancer and many AMMs auto reinvest fees for us. while Uniswap
    // does not auto reinvest fees but if we are building on Uniswap via Gamma strategies
    // then Gamma will auto reinvest the fees for us
    function removeAndSendFees(
        address poolAddress,
        address lpAddress,
        address destination
    ) external {
        // NOTE this function should return the amount of trading swap fees generated
        // by the tokens held in this account only, so the total amount of fees
        // generated by our contracts. Then we want to take 20% of this and
        // send it to Aelin Fee Module
        // so here's the logic. you put in 500K sUSD against 100K ABC. this is roughly 1M USD
        // the LPs in the pool earn 10% APY for the year. so there are 100K in trading fees for LPs
        // so AELIN is going to keep 20K in trading fees split between ABC and sUSD
        // the LPs will have the other 80K reinvested into the LP unless the AMM does that automatically
        // we have to know the amount of fees generated since the last time we took the aelin amount
        // a more detailed walkthrough:
        // each time a user goes to claim, we need to make sure that they are not claiming Aelin fees
        // 10 users each put in 100 sUSD for a total of 1000 sUSD against 10 ABC tokens
        // 6 month cliff, 18 month vesting period
        // contract has total of 2000 sUSD roughly and if it earns 10% a year you have
        // roughly 100 sUSD and 10 ABC tokens as interest
        // AELIN fees will be 20 sUSD and 2 ABC tokens
        // 9 months in everyone claims their share of the LPs that have vested
        // whenver someone vests their tokens we need to make sure that we are not giving
        // away Aelin fees
        // lets say the contract owns 10 LP tokens representing 2000 sUSD of tokens
        // each user owns 1 LP token. so after 9 months they are 3/18 months done vesting
        // after 9 months they can claim 3/18 of an LP token but the LP token might include some of hte fees
        // which have been generated. so when we let them claim we need to remove those fees and separate them

        // example implementation
        IWeightedPool balancerPool = IWeightedPool(poolAddress);
        // Get the pool tokens and their balances
        (address[] memory tokens, , ) = balancerVault.getPoolTokens(poolAddress);
        uint256 lpBalance = balancerPool.balanceOf(lpAddress);
        uint256 totalSupply = balancerPool.totalSupply();
        uint256 numTokens = tokens.length;
        uint256[] memory feesToSend = new uint256[](numTokens);
        // Calculate the total swap fees in the pool
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenFees = balancerPool.getSwapFeeAmount(tokens[i]);
            uint256 lpTokenFees = Math.mulDiv(tokenFees, lpBalance, totalSupply);
            // Calculate 20% of the fees
            feesToSend[i] = lpTokenFees.mul(20).div(100);
            // Withdraw the fees from the pool
            balancerPool.withdrawSwapFee(tokens[i], feesToSend[i]);
            // Transfer the fees to the destination address
            IERC20(tokens[i]).transfer(destination, feesToSend[i]);
        }
    }
}
