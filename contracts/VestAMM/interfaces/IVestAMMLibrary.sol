// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRateProvider} from "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";

// Integration notes
// we will deposit capital into AMMs all at once using deployPool
// or just addLiquidity if a pool already exists. Inside of these methods
// we will get back a specific amount of LP tokens. This will be the case
// even for Uniswap v3 since we will work with projects that wrap the NFT and return ERC20
// we will need to take the wrapped tokens and send them to a contract where they will be
// owned by NFTs held by each of the participants in the pool and maybe the protocol if
// they are keeping LP units. then we will need to call remove liquidity one user at a time
// when people call claim to vest their tokens. Each integration will need to have its own
// set of arguments passed depending on the AMM and how it works. For AMMs that automatically
// reinvest trading fees we will need to figure out a way to determine how much has been
// earned in fees and capture 10% of this amount as protocol fees. For AMMs that do not
// automatically reinvest trading fees we will need to collect the fees, distribute 10%
// to the AELIN protocol as fees and 90% back to the user
// this is all we need from an integration side with any AMM

interface IVestAMMLibrary {
    struct CreateNewPool {
        // name of the pool
        string name;
        // symbol of the pool
        string symbol;
        // NOTE these are the 2 tokens we are using
        IERC20[] tokens;
        // this is where you put the ratio between the 2 tokens
        uint256[] normalizedWeights;
        // not sure what this is
        IRateProvider[] rateProviders;
        // this is the fees for trading. probably 1% but TBD
        uint256 swapFeePercentage;
        // this is the LP owner which is the vAMM contract
        address owner;
    }

    struct AddLiquidity {
        IERC20[] tokens;
        uint256[] amounts;
        uint256 poolAmountOut;
    }

    // deploy pool also adds liquidity?
    function deployPool() external returns (bool);

    function addLiquidity(uint256, uint256) external returns (bool);

    function removeLiquidity(uint256, uint256) external returns (bool);

    function collectFees() external returns (bool);

    // TODO figure out which views we might want.
    // maybe a view for APY and fees earned or something
    function getPriceRatio(address, address) external view returns (uint256);

    function feesEarned() external view returns (uint256, uint256);

    function checkPoolExists() external view returns (bool);
}
