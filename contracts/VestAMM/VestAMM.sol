// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// NEED pausing and management features
import "../AelinVestingToken.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import "../libraries/MerkleTree.sol";
import "./interfaces/IVestAMM.sol";

contract VestAMM is AelinVestingToken, IVestAMM {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant AELIN_FEE = 1 * 10**18;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;

    AmmData public ammData;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;
    SingleRewardConfig[] public singleRewards;

    bool private calledInitialize;
    bool private baseComplete;
    bool private singleCompleteLength;

    address public vestAMMFeeModule;
    address public vestDAO;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess,
        address _vestAMMFeeModule,
        address _vestDAO
    ) external initOnce {
        // pool initialization checks
        // TODO how to name these
        // _setNameAndSymbol(string(abi.encodePacked("vAMM-", TBD)), string(abi.encodePacked("v-", TBD)));
        ammData = _ammData;
        vAmmInfo = _vAmmInfo;
        singleRewards = _singleRewards;
        dealAccess = _dealAccess;
        vestAMMFeeModule = _vestAMMFeeModule;
        vestDAO = _vestDAO;

        for (uint256 i; i < _vAmmInfo.vestingSchedule.length; ++i) {
            require(1825 days >= _vAmmInfo.vestingSchedule[i].vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _vAmmInfo.vestingSchedule[i].vestingPeriod, "max 5 year vesting");
            require(100e18 >= _vAmmInfo.vestingSchedule[i].investorShare, "max 100% to investor");
            require(0 <= _vAmmInfo.vestingSchedule[i].investorShare, "min 0% to investor");
            require(0 < _vAmmInfo.vestingSchedule[i].totalHolderTokens, "allocate tokens to schedule");
            require(_vAmmInfo.vestingSchedule[i].purchaseTokenPerDealToken > 0, "invalid deal price");
        }

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

    // checks if all assets deposited and sets deposit complete and starts deposit period if true
    function setDepositComplete() internal {
        depositComplete = true;
    }

    function _startDepositPeriod(
        uint256 _depositDuration,
        uint256 _vestingCliffPeriod,
        uint256 _vestingPeriod
    ) internal {
        purchaseExpiry = block.timestamp + _purchaseDuration;
        vestingCliffExpiry = purchaseExpiry + _vestingCliffPeriod;
        vestingExpiry = vestingCliffExpiry + _vestingPeriod;
        emit FullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiry, vestingExpiry);
    }

    // add a check to start deposit window
    // need to do a lot of checks. check right token. check right amount. set a flag when fully deposited
    function depositSingle(DepositToken[] calldata _depositTokens) external {
        // require single holder is the one calling it for the token needed
        // check if all are deposited and set deposit complete maybe which will start the deposit period
        for (uint i = 0; i < _depositTokens.length; i++) {
            IERC20(_depositTokens[i].token).transferFrom(msg.sender, address(this), _depositTokens[i].amount);
            emit TokenDeposited(_depositTokens[i].token, _depositTokens[i].amount);
        }
    }

    // can only be called before the deposit window begins
    function addSingle(DepositToken[] calldata _depositTokens) external onlyHolder {}

    // add a check to start deposit window
    // can only be called before the deposit window begins
    function removeSingle(DepositToken[] calldata _depositTokens) external onlyHolder depositIncomplete {}

    // add a check to start deposit window
    function depositBase() external {
        require(!baseComplete, "already deposited base asset");
        address baseAsset = ammData.baseAsset;

        uint256 balanceBeforeTransfer = IERC20(baseAsset).balanceOf(address(this));
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), baseAssetAmount);
        uint256 balanceAfterTransfer = IERC20(baseAsset).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        emit DepositPoolToken(baseAsset, msg.sender, amountPostTransfer);
        if (IERC20(baseAsset).balanceOf(address(this)) >= ammData.baseAssetAmount) {
            baseComplete = true;
        }

        // TODO add checks function for single depsoits complete as well to set deposit
        // complete and start the purchasing period
    }

    // takes out fees from LP side and single sided rewards and sends to official AELIN Fee Module
    // pairs against protocol tokens and deposits into AMM
    // sets LP tokens into vesting scheule for the investor
    // gives single sided rewards to user (with vesting schedule attached or not)
    // tracks % ownership of total LP assets for the Fee Module to track for claiming fees
    // note we may want to have a separate method for accepting in phase 0. tbd
    // note check access for NFT gated pools, merkle deal pools and private pools
    function acceptDeal(uint256 quoteAmount) external {}

    // collect the fees from AMMs that dont auto reinvest them
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {}

    // for investors to send in LP tokens (could be part of acceptDeal)
    // is there a case where protocols dont want to let people lock their existing liquidity
    function migrate() external {}

    // for investors at the end of phase 0 but only if they can deallocate,
    // otherwise it should not be necessary but we might use it anyways for v1 in both cases
    function settle() external {}

    // claim vested LP rewards
    function claimVestedLP() external {}

    // claim vested single sided rewards
    function claimVestedReward() external {}

    // to create the pool and deposit assets after phase 0 ends
    function createInitialLiquidity() external {
        require(vAMMInfo.hasLiquidityLaunch, "only for new liquidity");
        // ammData.ammContract based on the contract call the right libary deposit method
    }

    // to create the pool and deposit assets after phase 0 ends
    function createLiquidity() external {
        require(vAMMInfo.hasLiquidityLaunch == false, "only for existing liquidity");
    }

    function claimableUnderlyingTokens(uint256 _tokenId) public view returns (uint256) {
        VestingDetails memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedUnderlyingClaimable;

        if (schedule.lastClaimedAt > 0) {
            uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
            uint256 minTime = schedule.lastClaimedAt > vestingCliffExpiry ? schedule.lastClaimedAt : vestingCliffExpiry;

            if (maxTime > vestingCliffExpiry && minTime <= vestingExpiry) {
                uint256 underlyingClaimable = (schedule.share * (maxTime - minTime)) / vestingPeriod;

                // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
                // although it will generally never happen as solidity rounds down so there should always be a little bit left
                precisionAdjustedUnderlyingClaimable = underlyingClaimable >
                    IERC20(underlyingDealToken).balanceOf(address(this))
                    ? IERC20(underlyingDealToken).balanceOf(address(this))
                    : underlyingClaimable;
            }
        }
        return precisionAdjustedUnderlyingClaimable;
    }

    /**
     * @dev allows a user to claim their underlying deal tokens or a partial amount
     * of their underlying tokens once they have vested according to the schedule
     * created by the sponsor
     */
    function claimUnderlyingTokens(uint256 _tokenId) external {
        _claimUnderlyingTokens(msg.sender, _tokenId);
    }

    function _claimUnderlyingTokens(address _owner, uint256 _tokenId) internal {
        require(ownerOf(_tokenId) == _owner, "must be owner to claim");
        uint256 claimableAmount = claimableUnderlyingTokens(_tokenId);
        require(claimableAmount > 0, "no underlying ready to claim");
        vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        totalUnderlyingClaimed += claimableAmount;
        IERC20(underlyingDealToken).safeTransfer(_owner, claimableAmount);
        emit ClaimedUnderlyingDealToken(underlyingDealToken, _owner, claimableAmount);
    }

    function sendFeesToVestDAO(address[] tokens) external {
        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(vestDAO, IERC20(tokens[i]).balanceOf(address(this)));
        }
    }

    /**
     * @dev allows the purchaser to mint deal tokens. this method is also used
     * to send deal tokens to the sponsor. It may only be called from the pool
     * contract that created this deal
     */
    function mintVestingToken(address _to, uint256 _amount) external depositCompleted onlyPool {
        _mintVestingToken(_to, _amount, vestingCliffExpiry);
    }

    modifier initOnce() {
        require(!calledInitialize, "can only init once");
        calledInitialize = true;
        _;
    }

    modifier onlyHolder() {
        require(msg.sender == vAmmInfo.mainHolder, "only holder can access");
        _;
    }
}
