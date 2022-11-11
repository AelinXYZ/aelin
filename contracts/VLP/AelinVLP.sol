// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// NEED pausing and management features
import "../AelinERC20.sol";
import "../MinimalProxyFactory.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import "../libraries/MerkleTree.sol";

contract AelinVLP is AelinERC20, MinimalProxyFactory {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant AELIN_FEE = 1 * 10**18;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;

    bool private calledInitialize;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize() external initOnce {
        // pool initialization checks
    }

    modifier initOnce() {
        require(!calledInitialize, "can only init once");
        calledInitialize = true;
        _;
    }

    // deposit tokens to finalize the deal. you can send in all the different
    // tokens all at once or different times
    function finalizeVLP() external {}

    // takes out fees from LP side and single sided rewards and sends to official AELIN Fee Module
    // pairs against protocol tokens and deposits into AMM
    // sets LP tokens into vesting scheule for the investor
    // gives single sided rewards to user (with vesting schedule attached or not)
    // tracks % ownership of total LP assets for the Fee Module to track for claiming fees
    // note we may want to have a separate method for accepting in phase 0. tbd
    // note check access for NFT gated pools, merkle deal pools and private pools
    function acceptDeal() external {}

    // for investors to send in LP tokens (could be part of acceptDeal)
    function migrate() external {}

    // for investors at the end of phase 0 but only if they can deallocate,
    // otherwise it should not be necessary
    function settle() external {}

    // from the protocol side stops new entrants from participating and allows
    // them to make changes by calling withdraw and change rewards.
    // minimum of 15 mins when you pause something maybe to unpause.
    function pause() external {}

    function withdrawRewards() external {}

    function changeRewards() external {}

    // claim vested LP rewards
    function claimVestedLP() external {}

    // claim vested single sided rewards
    function claimVestedReward() external {}

    // to create the pool and deposit assets after phase 0 ends
    function createInitialLiquidity() external {}

    // to allow anyone to deposit LP tokens locked for 1 week
    // at a time to get access to the Fee Module with no boost
    function weeklyLock() external {}

    // views
}
