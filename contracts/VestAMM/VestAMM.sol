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
import "./interfaces/IVestAMM.sol";

contract VestAMM is AelinERC20, IVestAMM, MinimalProxyFactory {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant AELIN_FEE = 1 * 10**18;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;

    AMMData public ammData;
    LiquidityLaunch public liquidityLaunch;
    DealAccess public dealAccess;
    SingleRewardConfig[] public singleRewards;

    bool private calledInitialize;
    bool private depositComplete;

    address public vestAMMFeeModule;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        AMMData calldata _ammData,
        LiquidityLaunch calldata _liquidityLaunch,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess,
        address _vestAMMFeeModule
    ) external initOnce {
        // pool initialization checks
        ammData = _ammData;
        liquidityLaunch = _liquidityLaunch;
        dealAccess = _dealAccess;
        vestAMMFeeModule = _vestAMMFeeModule;
        singleRewards = _singleRewards;

        // Allow list logic
        // check if there's allowlist and amounts,
        // if yes, store it to `allowList` and emit a single event with the addresses and amounts
        AelinAllowList.initialize(_dealAccess.allowListInit, allowList);

        // NftCollection logic
        // check if the deal is nft gated
        // if yes, store it in `nftCollectionDetails` and `nftId` and emit respective events for 721 and 1155
        AelinNftGating.initialize(_dealAccess.nftCollectionRules, nftGating);

        require(!(allowList.hasAllowList && nftGating.hasNftList), "cant have allow list & nft");
        require(!(allowList.hasAllowList && _dealAccess.merkleRoot != 0), "cant have allow list & merkle");
        require(!(nftGating.hasNftList && _dealAccess.merkleRoot != 0), "cant have nft & merkle");
        require(!(bytes(_dealAccess.ipfsHash).length == 0 && _dealAccess.merkleRoot != 0), "merkle needs ipfs hash");
    }

    modifier initOnce() {
        require(!calledInitialize, "can only init once");
        calledInitialize = true;
        _;
    }

    // deposit tokens to finalize the deal. you can send in all the different
    // tokens all at once or different times
    function finalizeVestAMM(DepositToken[] calldata _depositTokens) external {
        // TODO handle deposit tokens and start the investment phase
        address baseAsset = ammData.baseAsset;
        uint256 baseAssetAmount = ammData.baseAssetAmount;

        require(!depositComplete, "already deposited the assets");
        require(IERC20(baseAsset).balanceOf(msg.sender) >= baseAssetAmount, "not enough balance");
        // Also how do we deal with people using rewards for the pool outside of vest
        if (singleRewards.length > 0) {}

        uint256 balanceBeforeTransfer = IERC20(baseAsset).balanceOf(address(this));
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), baseAssetAmount);
        uint256 balanceAfterTransfer = IERC20(baseAsset).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        emit DepositPoolToken(baseAsset, msg.sender, amountPostTransfer);

        // if (balanceAfterTransfer >= baseAssetAmount) {
        //     _startDepositPeriod(dealConfig.purchaseDuration, dealConfig.vestingCliffPeriod, dealConfig.vestingPeriod);
        // }

        // TODO require single sided deposits finalized as well
    }

    function _startDepositPeriod(
        uint256 _depositDuration,
        uint256 _vestingCliffPeriod,
        uint256 _vestingPeriod
    ) internal {
        // underlyingDepositComplete = true;
        // purchaseExpiry = block.timestamp + _purchaseDuration;
        // vestingCliffExpiry = purchaseExpiry + _vestingCliffPeriod;
        // vestingExpiry = vestingCliffExpiry + _vestingPeriod;
        // emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiry, vestingExpiry);
    }

    // takes out fees from LP side and single sided rewards and sends to official AELIN Fee Module
    // pairs against protocol tokens and deposits into AMM
    // sets LP tokens into vesting scheule for the investor
    // gives single sided rewards to user (with vesting schedule attached or not)
    // tracks % ownership of total LP assets for the Fee Module to track for claiming fees
    // note we may want to have a separate method for accepting in phase 0. tbd
    // note check access for NFT gated pools, merkle deal pools and private pools
    function acceptDeal() external {}

    // for investors to send in LP tokens (could be part of acceptDeal)
    // is there a case where protocols dont want to let people lock their existing liquidity
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
