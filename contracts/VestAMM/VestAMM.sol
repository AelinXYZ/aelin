// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// NEED pausing and management features
import "./VestVestingToken.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import "../libraries/MerkleTree.sol";
import "./interfaces/IVestAMM.sol";
import "./interfaces/IVestAMMLibrary.sol";

// TODO make sure the logic works with 80/20 balancer pools and not just when its 50/50
// TODO triple check all arguments start with _, casing is correct. well commented, etc
contract VestAMM is AelinVestingToken, IVestAMM {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant VEST_ASSET_FEE = 1 * 10**18;
    uint256 constant VEST_SWAP_FEE = 20 * 10**18;
    uint256 public depositExpiry;
    uint256 public lpFundingExpiry;
    uint256 public totalLPClaimed;
    uint8 private singleRewardsComplete;
    uint8 constant MAX_SINGLE_REWARDS = 10;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;
    AelinFeeModule public aelinFeeModule;

    uint256 public totalDeposited;
    uint256 investmentTokenPerBase;
    mapping(uint256 => bool) private finalizedDeposit;
    mapping(address => mapping(address => uint256)) holderDeposits;

    AmmData public ammData;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;
    SingleRewardConfig[] public singleRewards;

    bool private calledInitialize;
    bool private baseComplete;
    bool public isCancelled;
    bool public dealFunded;

    address public lpToken;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess,
        address _aelinFeeModule
    ) external initOnce {
        validateSingleRewards(singleRewards);
        validateVestingSchedules(_vAmmInfo.vestingSchedules);
        // pool initialization checks
        // TODO how to name these
        // _setNameAndSymbol(string(abi.encodePacked("vAMM-", TBD)), string(abi.encodePacked("v-", TBD)));
        ammData = _ammData;
        vAmmInfo = _vAmmInfo;
        // NOTE we may need to emit all the single rewards holders for the subgraph to know they need to make a deposit
        singleRewards = _singleRewards;
        dealAccess = _dealAccess;
        aelinFeeModule = _aelinFeeModule;

        // TODO if we are doing a liquidity growth round we need to read the prices of the assets
        // from onchain here and set the current price as the median price
        if (!_vAmmInfo.hasLaunchPhase) {
            investmentTokenPerBase = _ammData.ammLibrary.getPriceRatio(_ammData.investmentToken, _ammData.baseAsset);
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

    function setDepositComplete() internal {
        if (baseComplete == true && singleRewardsComplete == singleRewards.length) {
            depositComplete = true;
            depositExpiry = block.timestamp + vAmmInfo.depositWindow;
            lpFundingExpiry = depositExpiry + vAmmInfo.lpFundingWindow;
            emit DepositComplete(depositExpiry, lpFundingExpiry);
        }
    }

    function depositSingle(DepositToken[] calldata _depositTokens) external depositIncomplete {
        for (uint i = 0; i < _depositTokens.length; i++) {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_depositTokens[i].singleRewardIndex].holder == msg.sender,
                "not the right holder"
            );
            require(
                _depositTokens[i].token == singleRewards[_depositTokens[i].singleRewardIndex].token,
                "not the right token"
            );
            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
            holderDeposits[msg.sender][_depositTokens[i].token] += amountPostTransfer;
            emit TokenDeposited(_depositTokens[i].token, amountPostTransfer);
            if (
                amountPostTransfer >= singleRewards[_depositTokens[i].singleRewardIndex].rewardTokenTotal &&
                finalizedDeposit[_depositTokens[i].singleRewardIndex] == false
            ) {
                singleRewardsComplete += 1;
                finalizedDeposit[_depositTokens[i].singleRewardIndex] = true;
                emit TokenDepositComplete(_depositTokens[i].token);
            }
        }
        setDepositComplete();
    }

    function cancelVestAMM() onlyHolder depositIncomlete {
        for (uint i = 0; i < singleRewards.length; i++) {
            removeSingle(i);
        }
        if (holderDeposits[msg.sender][baseAsset] > 0) {
            IERC20(baseAsset).safeTransferFrom(address(this), vAmmInfo.mainHolder, holderDeposits[msg.sender][baseAsset]);
        }
        isCancelled = true;
    }

    function addSingle(SingleRewardConfig[] calldata _newSingleRewards) external onlyHolder depositIncomplete {
        require(_singleRewards.length + _newSingleRewards.length <= MAX_SINGLE_REWARDS, "max 10 single-sided rewards");
        validateSingleRewards(_newSingleRewards);
        for (uint i = 0; i < _newSingleRewards.length; i++) {
            singleRewards.push(_newSingleRewards[i]);
        }
    }

    function removeSingle(uint256[] calldata _removeIndexList) external depositIncomplete {
        for (uint i = 0; i < _removeIndexList.length; i++) {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_removeIndexList[i]].holder == msg.sender,
                "not the right holder"
            );
            if (finalizedDeposit[_removeIndexList[i]]) {
                finalizedDeposit[_removeIndexList[i]] = false;
                singleRewardsComplete -= 1;
            }
            uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][singleRewards[_removeIndexList[i]].token];
            uint256 singleHolderAmount = holderDeposits[singleRewards[_removeIndexList[i]].holder][
                singleRewards[_removeIndexList[i]].token
            ];
            if (mainHolderAmount > 0) {
                IERC20(singleRewards[_removeIndexList[i]].token).safeTransferFrom(
                    address(this),
                    vAmmInfo.mainHolder,
                    mainHolderAmount
                );
            }
            if (singleHolderAmount > 0) {
                IERC20(singleRewards[_removeIndexList[i]].token).safeTransferFrom(
                    address(this),
                    singleRewards[_removeIndexList[i]].holder,
                    singleHolderAmount
                );
            }
            finalizedDeposit[_removeIndexList[i]] = finalizedDeposit[singleRewards.length - 1];
            singleRewards[_removeIndexList[i]] = singleRewards[singleRewards.length - 1];
            delete finalizedDeposit[singleRewards.length - 1];
            singleRewards.pop();
            // TODO emit event for the subgraph tracking
        }
    }

    function depositBase() external onlyHolder depositIncomplete {
        require(!baseComplete, "already deposited base asset");
        address baseAsset = ammData.baseAsset;

        uint256 balanceBeforeTransfer = IERC20(baseAsset).balanceOf(address(this));
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), baseAssetAmount);
        uint256 balanceAfterTransfer = IERC20(baseAsset).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        holderDeposits[msg.sender][baseAsset] += amountPostTransfer;
        emit DepositPoolToken(baseAsset, msg.sender, amountPostTransfer);
        if (IERC20(baseAsset).balanceOf(address(this)) >= ammData.baseAssetAmount) {
            baseComplete = true;
        }

        setDepositComplete();
    }

    function withdrawExcessFunding(bool _isBase, uint256 _singleIndex) {
        // TODO emit any events?
        // TODO store baseAccepted under acceptDeal probably
        if (_isBase && holderDeposits[msg.sender][baseAsset] > (ammData.baseAssetAmount - baseAccepted)) {
            require(msg.sender == vAmmInfo.mainHolder, "not the right holder");
            uint256 excessAmount = holderDeposits[msg.sender][baseAsset] - (ammData.baseAssetAmount - baseAccepted);
            IERC20(ammData.baseAsset).safeTransferFrom(address(this), msg.sender, excessAmount);
        } else {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_singleIndex].holder == msg.sender,
                "not the right holder"
            );
            uint256 excessAmount = holderDeposits[msg.sender][singleRewards[_singleIndex].token] -
                (singleRewards[_singleIndex].rewardTokenTotal - singleRewards[_singleIndex].amountClaimed);
            IERC20(singleRewards[_singleIndex].token).safeTransferFrom(address(this), msg.sender, excessAmount);
        }
    }

    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _investmentTokenAmount,
        uint8 _vestingScheduleIndex
    ) external lock acceptDealOpen {
        // TODO how to check if an array item is empty in solidity.
        // it says access to a non-existing index will throw an exception. lets test this.
        require(vAmmInfo.vestingSchedule[_vestingScheduleIndex], "vesting schedule doesnt exist");
        address investmentToken = ammContract.investmentToken;
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
        mintVestingToken(msg.sender, depositTokenAmount);

        if (vAmmInfo.vestingSchedule[_vestingScheduleIndex].deallocation == Deallocation.None) {
            uint256 priceRatio = vAmmInfo.hasLaunchPhase ? vAmmInfo.investmentPerBase : investmentTokenPerBase;
            require(
                totalDeposited <=
                    (vAmmInfo.vestingSchedule[_vestingScheduleIndex].totalHolderTokens * priceRatio) /
                        IERC20(ammData.baseAsset).decimals(),
                "purchased amount > total"
            );
        }
        emit AcceptVestDeal(msg.sender, depositTokenAmount);
    }

    // to create the pool and deposit assets after phase 0 ends
    // TODO create a struct here that should cover every AMM. If needed to support more add a second struct
    function createInitialLiquidity(CreateNewPool _createPool, AddLiquidity _addLiquidity)
        external
        onlyHolder
        lpFundingWindow
    {
        require(vAMMInfo.hasLiquidityLaunch, "only for new liquidity");
        IVestAMMLibrary(ammData.ammLibrary).deployPool(_createPool, _addLiquidity);
        finalizeVesting();
    }

    // to create the pool and deposit assets after phase 0 ends
    function createLiquidity(AddLiquidity _addLiquidity) external onlyHolder lpFundingWindow {
        require(!vAMMInfo.hasLiquidityLaunche, "only for existing liquidity");
        IVestAMMLibrary(ammData.ammLibrary).addLiquidity(_addLiquidity, false);
        finalizeVesting();
    }

    function finalizeVesting() internal {
        dealFunded = true;
        for (uint256 i; i < _singleRewards.length; i++) {
            uint256 feeAmount = _singleRewards[i].reward (1e18 - deallocationPercent) / 1e18;
            sendFeesToAelin(, feeAmount);
        }
    }

    // for when the deal is cancelled
    function depositorWithdraw(uint256[] _tokenIds) external dealCancelled {
        for (uint256 i; i < _tokenIds.length; i++) {
            VestVestingToken memory schedule = vestingDetails[_tokenId];
            IERC20(investmentToken).safeTransferFrom(address(this), msg.sender, schedule.amountDeposited);
            emit Withdraw(msg.sender, schedule.amountDeposited);
        }
    }

    // withdraw deallocated
    function depositorDeallocWithdraw(uint256[] _tokenIds) external {
        require(depositComplete && block.timestamp > lpFundingExpiry, "not time to withdraw");
        for (uint256 i; i < _tokenIds.length; i++) {
            VestVestingToken memory schedule = vestingDetails[_tokenId];
            // TODO need to calculate and save this number during LP submission
            // and store it as an 18 decimals percentage 5e17 is 50%
            uint256 deallocationPercent;
            uint256 excessWithdrawAmount = (schedule.amountDeposited * 1e18) / deallocationPercent;
            IERC20(investmentToken).safeTransferFrom(address(this), msg.sender, excessWithdrawAmount);
            emit Withdraw(msg.sender, excessWithdrawAmount);
        }
    }

    // collect the fees from AMMs and send them to the Fee Module
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {}

    function claimableTokens(
        uint256 _tokenId,
        ClaimType _claimType,
        uint256 _claimIndex
    ) public view returns (uint256) {
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedClaimable;
        uint256 lastClaimedAt = _claimType == ClaimType.Single
            ? schedule.lastClaimedAtRewardList[_claimIndex]
            : schedule.lastClaimedAt;

        if (lastClaimedAt > 0) {
            uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
            uint256 minTime = lastClaimedAt > depositExpiry ? lastClaimedAt : depositExpiry;

            if (maxTime > depositExpiry && minTime <= vestingExpiry) {
                // NOTE that schedule.share needs to be updated
                // to be the total deposited / global total somehow without requiring a settle method
                // NOTE this math is wrong probably. need to figure out what to do with Math here to avoid issues
                // TODO check how share is used on the other contracts
                uint256 lpClaimable = (((schedule.amountDeposited * 10**depositTokenDecimals) / totalDeposited) *
                    (maxTime - minTime)) / vestingPeriod;

                // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
                // although it will generally never happen as solidity rounds down so there should always be a little bit left
                precisionAdjustedClaimable = lpClaimable > IERC20(lpToken).balanceOf(address(this))
                    ? IERC20(lpToken).balanceOf(address(this))
                    : lpClaimable;
            }
        }
        return precisionAdjustedClaimable;
    }

    /**
     * @dev allows a user to claim their all their vested tokens across a single NFT
     */
    function claimAllTokens(uint256 _tokenId) external {
        claimLPTokens(_tokenId);
        for (uint256 i; i < singleRewards.length; i++) {
            claimRewardToken(_tokenId, i);
        }
    }

    /**
     * @dev allows a user to claim their all their vested tokens across many NFTs
     */
    function claimManyNFTs(uint256[] _tokenIds) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            claimAllTokens(_tokenIds[i]);
        }
    }

    /**
     * @dev allows a user to claim their LP tokens or a partial amount
     * of their LP tokens once they have vested according to the schedule
     * created by the protocol
     */
    function claimLPTokens(uint256 _tokenId) external {
        _claimTokens(msg.sender, _tokenId, ClaimType.Base, 0);
    }

    /**
     * @dev allows a user to claim their single sided reward tokens or a partial amount
     * of their single sided reward tokens once they have vested according to the schedule
     */
    function claimRewardToken(uint256 _tokenId, uint256 _claimIndex) external {
        _claimTokens(msg.sender, _tokenId, ClaimType.Single, _claimIndex);
    }

    function _claimTokens(
        address _owner,
        uint256 _tokenId,
        ClaimType _claimType,
        uint256 _claimIndex
    ) internal {
        require(ownerOf(_tokenId) == _owner, "must be owner to claim");
        // TODO double check this doesn't error if there are no single sided rewards
        uint256 claimableAmount = claimableTokens(_tokenId, _claimType, _claimIndex);
        require(claimableAmount > 0, "no lp tokens ready to claim");
        if (_claimType == ClaimType.Base) {
            vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
            totalLPClaimed += claimableAmount;
        } else {
            vestingDetails[_tokenId].lastClaimedAtRewardList[_claimIndex] = block.timestamp;
            // TODO like we do for the LP positions, track totals for each single reward type claimed
            // in a mapping we can query from UI
        }
        address claimToken = _claimType == ClaimType.Base ? lpToken : singleRewards[_claimIndex].token;
        IERC20(claimToken).safeTransfer(_owner, claimableAmount);
        emit ClaimedToken(claimToken, _owner, claimableAmount, _claimType);
    }

    function sendFeesToAelin(address _token, uint256 _amount) external {
        IERC20(_token).approve(aelinFeeModule, _amount);
        AelinFeeModule(aelinFeeModule).sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    function validateSingleRewards(SingleRewardConfig[] _singleRewards) internal {
        require(_singleRewards.length <= MAX_SINGLE_REWARDS, "max 10 single-sided rewards");
        for (uint256 i; i < _singleRewards.length; i++) {
            // NOTE can the single holder be null? the main holder can do this when they are
            // the single as well maybe.
            // Also we need to potentially validate more of the fields like migration rules
            // if we use the migration stuff at all for v1
            require(rewardToken != address(0), "cannot pass null address");
            // DO we need this field
            require(rewardPerQuote > 0, "rpq: must pass an amount");
            require(amountClaimed == 0, "amount claimed must be 0");
            require(rewardTokenTotal > 0, "rtt: must pass an amount");
            VestingSchedule[] vestingSchedule = [_singleRewards.vestingData];
            validateVestingSchedules(vestingSchedule);
        }
    }

    function validateVestingSchedules(VestingSchedule[] _vestingSchedules) internal {
        for (uint256 i; i < _vestingSchedules.length; ++i) {
            require(1825 days >= _vestingSchedules[i].vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _vestingSchedules[i].vestingPeriod, "max 5 year vesting");
            require(100 * 10**18 >= _vestingSchedules[i].investorShare, "max 100% to investor");
            require(0 <= _vestingSchedules[i].investorShare, "min 0% to investor");
            require(0 < _vestingSchedules[i].totalHolderTokens, "allocate tokens to schedule");
            require(_vestingSchedules[i].purchaseTokenPerDealToken > 0, "invalid deal price");
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
        // NOTE there is maybe a better way to do this
        uint256[] singleDepositExpiry;
        for (uint i = 0; i < singleRewards.length; i++) {
            singleDepositExpiry[i] = depositExpiry;
        }
        _mintVestingToken(_to, _amount, depositExpiry, singleDepositExpiry);
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

    modifier dealCancelled() {
        require(
            isCancelled ||
                (!depositComplete && block.timestamp > depositExpiry) ||
                (!dealFunded && block.timestamp > lpFundingExpiry),
            "deal not cancelled"
        );
        _;
    }

    modifier lpFundingWindow() {
        require(!isCancelled, "deal is cancelled");
        // TODO double check < vs <= matches everywhere
        require(
            depositComplete && block.timestamp > depositExpiry && block.timestamp <= lpFundingExpiry,
            "not in funding window"
        );
        _;
    }

    modifier acceptDealOpen() {
        require(!isCancelled, "deal is cancelled");
        // TODO double check < vs <= matches everywhere
        require(depositComplete && block.timestamp <= depositExpiry, "not in deposit window");
        _;
    }
}
