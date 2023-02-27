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
    uint256 constant VEST_ASSET_FEE = 1 * 10**18;
    uint256 constant VEST_SWAP_FEE = 10 * 10**18;
    uint256 public depositExpiry;
    uint256 public lpFundingExpiry;
    uint256 public totalLPClaimed;
    uint8 private singleRewardsComplete;
    uint8 constant MAX_SINGLE_REWARDS = 10;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;

    uint256 public totalDeposited;
    mapping(address => uint256) public depositTokensPerUser;
    mapping(uint256 => bool) private finalizedDeposit;

    AmmData public ammData;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;
    SingleRewardConfig[] public singleRewards;

    bool private calledInitialize;
    bool private baseComplete;

    address public vestAMMFeeModule;
    address public vestDAO;
    address public lpToken;

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
        require(_singleRewards.length <= MAX_SINGLE_REWARDS, "max 10 single-sided rewards");
        // pool initialization checks
        // TODO how to name these
        // _setNameAndSymbol(string(abi.encodePacked("vAMM-", TBD)), string(abi.encodePacked("v-", TBD)));
        ammData = _ammData;
        vAmmInfo = _vAmmInfo;
        // NOTE we may need to emit all the single rewards holders for the subgraph to know they need to make a deposit
        singleRewards = _singleRewards;
        dealAccess = _dealAccess;
        vestAMMFeeModule = _vestAMMFeeModule;
        vestDAO = _vestDAO;

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

    function setDepositComplete() internal {
        if (baseComplete == true && singleRewardsComplete == singleRewards.length) {
            depositComplete = true;
            depositExpiry = block.timestamp + vAmmInfo.depositWindow;
            emit DepositComplete(depositExpiry);
        }
    }

    // add a check to start deposit window
    // need to do a lot of checks. check right token. check right amount. set a flag when fully deposited
    function depositSingle(DepositToken[] calldata _depositTokens) external {
        for (uint i = 0; i < _depositTokens.length; i++) {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_depositTokens[i].singleRewardIndex].holder == msg.sender,
                "not the right holder"
            );
            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
            emit TokenDeposited(_depositTokens[i].token, amountPostTransfer);
            if (amountPostTransfer >= singleRewards[_depositTokens[i].singleRewardIndex].rewardTokenTotal) {
                singleRewardsComplete += 1;
                finalizedDeposit[_depositTokens[i].singleRewardIndex] = true;
                emit TokenDepositComplete(_depositTokens[i].token);
            }
        }
        setDepositComplete();
    }

    // TODO cancel deal button callable before the deposit is complete. can we also cancel in the middle? hmm
    function cancelVestAMM() onlyHolder depositIncomlete {}

    function addSingle(SingleRewardConfig[] calldata _newSingleRewards) external onlyHolder depositIncomplete {
        require(_singleRewards.length + _newSingleRewards.length <= MAX_SINGLE_REWARDS, "max 10 single-sided rewards");
        for (uint i = 0; i < _newSingleRewards.length; i++) {
            singleRewards.push(_newSingleRewards[i]);
        }
    }

    function removeSingle(uint256[] calldata _removeIndexList) external depositIncomplete {
        // TODO maybe let them take the funds back to the holder if it was already funded. hmmm
        for (uint i = 0; i < _removeIndexList.length; i++) {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_removeIndexList[i]].holder == msg.sender,
                "not the right holder"
            );
            // require(finalizedDeposit[_removeIndexList[i]] == false, "deposit has been finalized");
            // if (finalizedDeposit[_removeIndexList[i]] == true) { return funds to holder here }
            singleRewards[_removeIndexList[i]] = singleRewards[singleRewards.length - 1];
            singleRewards.pop();
        }
    }

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
        setDepositComplete();
    }

    // takes out fees from LP side and single sided rewards and sends to official AELIN Fee Module
    // pairs against protocol tokens and deposits into AMM
    // sets LP tokens into vesting scheule for the investor
    // gives single sided rewards to user (with vesting schedule attached or not)
    // tracks % ownership of total LP assets for the Fee Module to track for claiming fees
    // note we may want to have a separate method for accepting in phase 0. tbd
    // note check access for NFT gated pools, merkle deal pools and private pools
    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _investmentTokenAmount,
        uint8 _vestingScheduleIndex
    ) external lock acceptDealOpen {
        // TODO how to check if an array item is empty in solidity.
        // it says access to a non-existing index will throw an exception. lets test this.
        require(vAmmInfo.vestingSchedule[_vestingScheduleIndex], "vesting schedule doesnt exist");
        address investmentToken = ammContract.quoteAsset;
        require(IERC20(investmentToken).balanceOf(msg.sender) >= _investmentTokenAmount, "balance too low");
        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _investmentTokenAmount);
        } else if (allowList.hasAllowList) {
            require(_investmentTokenAmount <= allowList.amountPerAddress[msg.sender], "more than allocation");
            allowList.amountPerAddress[msg.sender] -= _investmentTokenAmount;
        } else if (dealAccess.merkleRoot != 0) {
            MerkleTree.purchaseMerkleAmount(_merkleData, trackClaimed, _investmentTokenAmount, dealAccess.merkleRoot);
        }
        uint256 balanceBeforeTransfer = IERC20(investmentToken).balanceOf(address(this));
        IERC20(investmentToken).safeTransferFrom(msg.sender, address(this), _investmentTokenAmount);
        uint256 balanceAfterTransfer = IERC20(investmentToken).balanceOf(address(this));
        uint256 depositTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;
        totalDeposited += depositTokenAmount;
        depositTokensPerUser[msg.sender] += depositTokenAmount;
        // NOTE is there a problem with issuing multiple NFTs per user
        // we should find a way to add to their existing one if it exists
        // we do not want to reuse the AelinVestToken contract exactly here. what we want
        // is a NFT that is tied to a mapping that has a few fields.
        // 1. Total deposited by an address (one NFT per address)
        // this amount will be tied to the total deposited overall
        // as an indicator of % ownership of the pool and rewards. In addition to a claim on LP tokens
        // there should be a single sided rewards claim function that looks at the % overall held by a NFT
        // the owner must be the one to claim who is holding the NFT which is transferrable
        // the mint function itself should just update their existing NFT if it already exists for their wallet
        // the NFT also has to separately track for each single sided reward whether it has been claimed and what the
        // vesting schedule is. keep in mind for this design there are a max of 10 single sided rewards
        mintVestingToken(msg.sender, depositTokenAmount);
        // mint a NFT which will use a formula to calculate amounts and all single rewards
        // will be tied to this NFT

        if (vAmmInfo.vestingSchedule[_vestingScheduleIndex].deallocation == Deallocation.None) {
            // NOTE this math is not right but just a placeholder for now
            require(
                totalDeposited <=
                    vAmmInfo.vestingSchedule[_vestingScheduleIndex].totalHolderTokens * vAMMInfo.initialQuotePerBase,
                "purchased amount > total"
            );
        }
        emit AcceptVestDeal(msg.sender, depositTokenAmount);
    }

    // collect the fees from AMMs and send them to the Fee Module
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {}

    // for investors at the end of phase 0 but only if they can deallocate,
    // otherwise it should not be necessary but we might use it anyways for v1 in both cases
    // this method will be important as it will set a global total value that will be used in the claim function
    // NOTE maybe we dont need settle at all. tbd
    function settle() external {}

    // to create the pool and deposit assets after phase 0 ends
    function createInitialLiquidity() external {
        require(vAMMInfo.hasLiquidityLaunch, "only for new liquidity");
        // ammData.ammContract based on the contract call the right libary deposit method
    }

    // to create the pool and deposit assets after phase 0 ends
    function createLiquidity() external {
        require(vAMMInfo.hasLiquidityLaunch == false, "only for existing liquidity");
    }

    // claim vested LP rewards
    function claimVestedLP() external {}

    // claim vested single sided rewards
    function claimVestedReward() external {}

    /**
     * @dev allows a user to claim their LP tokens or a partial amount
     * of their LP tokens once they have vested according to the schedule
     * created by the protocol
     */
    function claimRewardTokens(uint256 _tokenId) external {
        _claimLPTokens(msg.sender, _tokenId);
        // TODO change this as needed to claim all single at once after writing the single claim
        _claimVestedRewards(msg.sender, _tokenId);
    }

    function claimableLPTokens(uint256 _tokenId) public view returns (uint256) {
        VestingDetails memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedLPClaimable;

        if (schedule.lastClaimedAt > 0) {
            uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
            uint256 minTime = schedule.lastClaimedAt > vestingCliffExpiry ? schedule.lastClaimedAt : vestingCliffExpiry;

            if (maxTime > vestingCliffExpiry && minTime <= vestingExpiry) {
                // NOTE that schedule.share needs to be updated
                // to be the total deposited / global total somehow without requiring a settle method
                uint256 lpClaimable = (schedule.share * (maxTime - minTime)) / vestingPeriod;

                // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
                // although it will generally never happen as solidity rounds down so there should always be a little bit left
                precisionAdjustedLPClaimable = lpClaimable > IERC20(lpToken).balanceOf(address(this))
                    ? IERC20(lpToken).balanceOf(address(this))
                    : lpClaimable;
            }
        }
        return precisionAdjustedLPClaimable;
    }

    /**
     * @dev allows a user to claim their LP tokens or a partial amount
     * of their LP tokens once they have vested according to the schedule
     * created by the protocol
     */
    function claimLPTokens(uint256 _tokenId) external {
        _claimLPTokens(msg.sender, _tokenId);
    }

    function _claimLPTokens(address _owner, uint256 _tokenId) internal {
        require(ownerOf(_tokenId) == _owner, "must be owner to claim");
        uint256 claimableAmount = claimableLPTokens(_tokenId);
        require(claimableAmount > 0, "no lp tokens ready to claim");
        vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        totalLPClaimed += claimableAmount;
        IERC20(lpToken).safeTransfer(_owner, claimableAmount);
        emit ClaimedLPToken(lpToken, _owner, claimableAmount);
    }

    function sendFeesToVestDAO(address[] tokens) external {
        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(vestDAO, IERC20(tokens[i]).balanceOf(address(this)));
        }
    }

    /**
     * @dev allows the purchaser to mint a NFT representing their share of the LP tokens
     * the NFT will be tied to storage data in this contract. We need 4 numbers for the
     * vesting system to work. 1) the investors amount contributed. 2) the total target raise.
     * 3) the total amount contributed and 4) the number of LP tokens they earn.
     * After the LP funding window is done whenever a user calls transfer or claim for the
     * first time we can update all the NFT object data to show their exact vesting amounts.
     * we can use a bitmap to efficiently calculate if they have claimed or transferred their NFT yet.
     * the bitmap will use the ID of the NFT we issued them as the index. if they have claimed
     * their index will be set to 1. This system gets rid of the need to have a settle step where the
     * deallocation is managed like we do in the regular Aelin pools.
     */
    function mintVestingToken(address _to, uint256 _amount) internal {
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

    modifier depositIncomplete() {
        require(!depositComplete, "too late: deposit complete");
        _;
    }

    modifier acceptDealOpen() {
        // TODO double check < vs <= matches everywhere
        require(depositComplete && block.timestamp <= depositExpiry, "not in deposit window");
        _;
    }
}
