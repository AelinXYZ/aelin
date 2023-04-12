// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// NEED pausing and management features
import "./VestVestingToken.sol";
import "./VestAMMMultiRewards.sol";
import {AelinVestingToken} from "contracts/AelinVestingToken.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import "../libraries/MerkleTree.sol";
import "./interfaces/IVestAMM.sol";
import "./interfaces/IVestAMMLibrary.sol";
import "contracts/interfaces/balancer/IBalancerPool.sol";

// we will have a modified staking rewards contract that reads the balances of each investor in the locked LP alongside which bucket they are in
// so you can distribute protocol fees to locked LPs and also do highly targeted rewards just to specific buckets if you want
// TODO add in a curve multi rewards contract to the VestAMM so that you can distribute protocol fees to holders
// NOTE can we do this without any restrictions???
// TODO proper commenting everywhere in the natspec format
// TODO write an initial test that checks the ability to start a vAMM and deposit base and single reward tokens
// TODO make sure the logic works with 80/20 balancer pools and not just when its 50/50
// TODO triple check all arguments start with _, casing is correct. well commented, etc
contract VestAMM is AelinVestingToken, IVestAMM {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant VEST_ASSET_FEE = 1 * 10**18;
    uint256 constant VEST_SWAP_FEE = 20 * 10**18;
    uint256 public depositExpiry;
    uint256 public lpFundingExpiry;
    uint256 public lpDepositTime;
    uint256 public totalLPClaimed;
    uint256 public holderTokenTotal;
    uint256 public maxInvTokens;
    uint256 public amountBaseDeposited;
    uint8 private numVestingSchedules;
    mapping(uint8 => uint256) public maxInvTokensPerVestSchedule;
    mapping(uint8 => uint256) public depositedPerVestSchedule;
    mapping(uint8 => bool) public isVestingScheduleFull;
    mapping(address => mapping(uint8 => mapping(uint8 => uint256))) public holderDeposits;
    uint8 private singleRewardsComplete;
    uint8 public numSingleRewards;
    uint8 constant MAX_SINGLE_REWARDS = 6;
    uint8 constant MAX_LP_VESTING_SCHEDULES = 4;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;
    // TODO
    // AelinFeeModule public aelinFeeModule;

    uint256 public totalDeposited;
    uint256 investmentTokenPerBase;

    AmmData public ammData;
    VestAMMMultiRewards public vestAmmMultiRewards;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;

    bool private calledInitialize;
    bool private baseComplete;
    bool public isCancelled;

    address public lpToken;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess,
        address _aelinFeeModule
    ) external initOnce {
        _validateSchedules(_vAmmInfo.lpVestingSchedules);
        // pool initialization checks
        // TODO how to name these
        // _setNameAndSymbol(string(abi.encodePacked("vAMM-", TBD)), string(abi.encodePacked("v-", TBD)));
        ammData = _ammData;
        vAmmInfo = _vAmmInfo;
        dealAccess = _dealAccess;
        aelinFeeModule = _aelinFeeModule;
        // TODO work on the rewards logic
        // TODO research the limit of how many rewards tokens you can distribute
        vestAmmMultiRewards = new VestAMMMultiRewards(address(this));

        // TODO if we are doing a liquidity growth round we need to read the prices of the assets
        // from onchain here and set the current price as the median price
        // TODO do a require check to make sure the pool exists if they are doing a liquidity growth
        if (!_vAmmInfo.hasLaunchPhase) {
            // we need to pass in data to check if the pool exists. ammData is a placeholder but not the right argument
            require(_ammData.ammLibrary.checkPoolExists(ammData), "pool does not exist");
            investmentTokenPerBase = _ammData.ammLibrary.getPriceRatio(_ammData.investmentToken, _ammData.baseAsset);
        }
        // LP vesting schedule array up to 4 buckets
        // each bucket will have a token total in the protocol tokens
        // this loop calculates the maximum number of investment tokens that will be accepted
        // based on the price ratio at the time of creation or the price defined in the
        // launch struct for new protocols without liquidity
        uint256 invPerBase = _vAmmInfo.hasLaunchPhase ? _vAmmInfo.investmentPerBase : investmentTokenPerBase;

        numVestingSchedules = vAmmInfo.lpVestingSchedules.length;
        for (uint i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            numSingleRewards += vAmmInfo.lpVestingSchedules[i].singleVestingSchedules.length;
            holderTokenTotal += vAmmInfo.lpVestingSchedules[i].totalBaseTokens;
            // the maximum number of investment tokens investors can deposit per vesting schedule
            // this is important for the deallocation logic and the ability to invest more than the cap
            // our logic for deallocation will be that all the schedules need to be full before you can
            // over allocate to any single bucket. BUT the protocol can choose to not allow deallocation
            // and only allow each bucket to fill up to the max
            maxInvTokensPerVestSchedule[i] =
                (vAmmInfo.lpVestingSchedules[i].totalBaseTokens * invPerBase) /
                10**IERC20(ammData.baseAsset).decimals();
            // NOTE is this needed?
            maxInvTokens += maxInvTokensPerVestSchedule[i];
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
        if (baseComplete == true && singleRewardsComplete == numSingleRewards) {
            depositComplete = true;
            depositExpiry = block.timestamp + vAmmInfo.depositWindow;
            lpFundingExpiry = depositExpiry + vAmmInfo.lpFundingWindow;
            emit DepositComplete(depositExpiry, lpFundingExpiry);
        }
    }

    // TODO create a view that tells you what arguments to pass as a single rewards holder to this method
    // when you go to deposit a single reward, maybe we loop through each of the 5 vesting schedules 
    // and then we also loop through each of the 8 single rewards.
    // we have the main LP vesting schedules
    // we hae an array of single rewards tied to each schedule. 
    // we need to track all deposits and who sent them
    // we need to restrict deposits to the right single holder or the main holder
    // later on, we need to reimburse the single holder or the main holder if there are tokens left
    // we have up to 41 deposits to track. 8 single rewards per bucket and 5 buckets. plus the base asset
    // mapping(uint8 => bool) public finalizedDeposit;
    // mapping(address => mapping(uint8 => uint256)) public holderDeposits;
    // 41 bits where each bit says 1 if deposited and 0 if not deposited
    // the first bit is for the base asset
    // 1 + lp index * 8 + index in the single rewards array + 1
    // 1 + 0 + 3 + 1 = 5
    // [1[1,2,<<3>>,4,5,6,7,8],2,3,4,5[1,2,3,4,5,6,<<7>>,8]]
    // 1 + 4 * 8 + 6 + 1 = 40 
    // [1[1,2,3,4,5,6,7,8],2,3,4,5[1,2,3,4,5,6,<<7>>,8]]
    // when you fund the single deposit you pass in the value 1 to 41 which will tell us which token you are funding
    // you can get the value off a view function or something we can add below

    // check when base + all single deposits are finalized
    // deposit single
    // add single
    // remove single
    // be able to claim with NFT
    // reimburse if extra single left
    // up to 4 LP buckets and each bucket has up to 6 rewards so there are 24 possible locations for a single reward
    
    function depositSingle(DepositToken[] calldata _depositTokens) external depositIncomplete {
        for (uint i = 0; i < _depositTokens.length; i++) {
            SingleVestingSchedule singleVestingSchedule = vAmmInfo.lpVestingSchedules[_depositTokens[i].vestingScheduleIndex].singleVestingSchedules[_depositTokens[i].singleRewardIndex];
            require(msg.sender == vAmmInfo.mainHolder || singleVestingSchedule.singleHolder == msg.sender,
                "not the right holder"
            );
            require(_depositTokens[i].token == singleVestingSchedule.rewardToken, "not the right token");
            require(IERC20(_depositTokens[i].token).balanceOf(msg.sender) > _depositTokens[i].amount, "not enough balance");
            require(!singleVestingSchedule.finalizedDeposit, "deposit already finalized");
            // check deposit is not finalized here
            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;

            holderDeposits[msg.sender][_depositTokens[i].vestingScheduleIndex][_depositTokens[i].singleRewardIndex] += amountPostTransfer;

            emit SingleRewardDeposited(msg.sender, _depositTokens[i].vestingScheduleIndex, _depositTokens[i].singleRewardIndex, _depositTokens[i].token, amountPostTransfer);
            if (holderDeposits[msg.sender][_depositTokens[i].vestingScheduleIndex][_depositTokens[i].singleRewardIndex] >= singleVestingSchedule.totalSingleTokens) {
                singleRewardsComplete += 1;
                singleVestingSchedule.finalizedDeposit = true;
                emit SingleDepositComplete(_depositTokens[i].token, _depositTokens[i].vestingScheduleIndex, _depositTokens[i].singleRewardIndex);
            }
        }
        setDepositComplete();
    }

    // TODO check if we need modifier
    // function cancelVestAMM()external onlyHolder depositIncomlete {
    function cancelVestAMM() external onlyHolder {
        for (uint i = 0; i < singleRewards.length; i++) {
            removeIndexes[i] = i;
        }
        removeSingle(removeIndexes);
        if (amountBaseDeposited > 0) {
            IERC20(baseAsset).safeTransferFrom(address(this), vAmmInfo.mainHolder, amountBaseDeposited);
        }
        isCancelled = true;
    }

    function addSingle(SingleRewardConfig[] calldata _newSingleRewards) external onlyHolder depositIncomplete {
        _validateAddSingle(_newSingleRewards);
    }

    function removeSingle(uint256[] calldata _removeIndexList) external depositIncomplete {
        for (uint i = 0; i < _removeIndexList.length; i++) {
            require(
                msg.sender == vAmmInfo.mainHolder || singleRewards[_removeIndexList[i]].singleHolder == msg.sender,
                "not the right holder"
            );
            uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][_removeIndexList[i]];
            uint256 singleHolderAmount = holderDeposits[singleRewards[_removeIndexList[i]].singleHolder][
                _removeIndexList[i]
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
                    singleRewards[_removeIndexList[i]].singleHolder,
                    singleHolderAmount
                );
            }
            emit SingleRemoved(
                _removeIndexList[i],
                singleRewards[_removeIndexList[i]].token,
                singleRewards[_removeIndexList[i]].rewardTokenTotal,
                mainHolderAmount,
                singleHolderAmount
            );

            if (finalizedDeposit[_removeIndexList[i]]) {
                singleRewardsComplete -= 1;
            }
            finalizedDeposit[_removeIndexList[i]] = finalizedDeposit[singleRewards.length - 1];
            singleRewards[_removeIndexList[i]] = singleRewards[singleRewards.length - 1];
            holderDeposits[vAmmInfo.mainHolder][_removeIndexList[i]] = holderDeposits[vAmmInfo.mainHolder][
                singleRewards.length - 1
            ];
            holderDeposits[singleRewards[_removeIndexList[i]].singleHolder][_removeIndexList[i]] = holderDeposits[
                singleRewards[_removeIndexList[i]].singleHolder
            ][singleRewards.length - 1];

            delete holderDeposits[singleRewards[_removeIndexList[i]].singleHolder][singleRewards.length - 1];
            delete holderDeposits[vAmmInfo.mainHolder][singleRewards.length - 1];

            finalizedDeposit.pop();
            singleRewards.pop();
        }
    }

    function depositBase() external onlyHolder depositIncomplete {
        require(!baseComplete, "already deposited base asset");
        address baseAsset = ammData.baseAsset;

        uint256 balanceBeforeTransfer = IERC20(baseAsset).balanceOf(address(this));
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), baseAssetAmount);
        uint256 balanceAfterTransfer = IERC20(baseAsset).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        amountBaseDeposited += amountPostTransfer;
        emit DepositPoolToken(baseAsset, msg.sender, amountPostTransfer);
        if (amountBaseDeposited >= ammData.baseAssetAmount) {
            baseComplete = true;
        }

        setDepositComplete();
    }

    // TODO circle back to this method
    function withdrawExcessFunding(bool _isBase, uint256 _singleIndex) external {
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
            // TODO deleted amountClaimed from single rewards. maybe add back if needed. tbd
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
    ) external lock acceptDealOpen vestingScheduleOpen(_vestingScheduleIndex, _investmentTokenAmount) {
        // TODO how to check if an array item is empty in solidity.
        // it says access to a non-existing index will throw an exception. lets test this.
        require(!!vAmmInfo.vestingSchedule[_vestingScheduleIndex], "vesting schedule doesnt exist");
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
        depositedPerVestSchedule[_vestingScheduleIndex] += depositTokenAmount;

        if (
            !isVestingScheduleFull[_vestingScheduleIndex] &&
            depositedPerVestSchedule[_vestingScheduleIndex] + _investmentTokenAmount >=
            maxInvTokensPerVestSchedule[_vestingScheduleIndex]
        ) {
            isVestingScheduleFull[_vestingScheduleIndex] = true;
        }
        totalDeposited += depositTokenAmount;
        // VestAMMMultiRewards.stake(depositTokenAmount);
        mintVestingToken(msg.sender, depositTokenAmount, _vestingScheduleIndex);

        emit AcceptVestDeal(msg.sender, depositTokenAmount, _vestingScheduleIndex);
    }

    // to create the pool and deposit assets after phase 0 ends
    // TODO create a struct here that should cover every AMM. If needed to support more add a second struct
    function createInitialLiquidity(IBalancerPool.CreateNewPool _createPool, bytes memory _userData)
        external
        onlyHolder
        lpFundingWindow
    {
        require(vAMMInfo.hasLiquidityLaunch, "only for new liquidity");
        // NOTE for this method we are going to want to pass in a lot of the arguments from
        // data stored in the contract. it won't be a pure pass through like we have now
        // at this stage in the development process
        IVestAMMLibrary(ammData.ammLibrary).deployPool(_createPool, _userData);
        finalizeVesting();
    }

    // to create the pool and deposit assets after phase 0 ends
    function createLiquidity(IBalancerPool.AddLiquidity _addLiquidity) external onlyHolder lpFundingWindow {
        require(!vAMMInfo.hasLiquidityLaunche, "only for existing liquidity");
        IVestAMMLibrary(ammData.ammLibrary).addLiquidity(_addLiquidity);
        finalizeVesting();
    }

    function finalizeVesting() internal {
        lpDepositTime = block.timestamp;
        // 20% fee of all trading fees from the LP tokens. this gets taken out later
        // 1% fee for assets going through VestAMM
        sendFeesToAelin(ammData.baseAsset, feeAmount);
        for (uint256 i; i < _singleRewards.length; i++) {
            // NOTE this assumes all the reward tokens were claimed
            // we need to update this so that it calculates the share of investment token vs the actual raise
            // so a pool trying to raise 1M sUSD but only get 500K sUSD means that we need to pro-rate the fee
            uint256 feeAmount = (_singleRewards[i].rewardTokenTotal * VEST_ASSET_FEE) / 1e18;
            sendFeesToAelin(_singleRewards[i].token, feeAmount);
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
    // NOTE maybe this is a public function so we can call it internally when
    // they claim if they haven't yet withdrawn their deallocated amount
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
    function collectAllFees(uint256 tokenId) public returns (uint256 amount0, uint256 amount1) {
        // we have to call the AMM to check the amount of fees generated since the last time we did this
        // we need to send X% of those fees to the Aelin Fee Module
    }

    // logic
    // you have LP tokens which may or may not be on vesting schedules to claim
    // you have single sided reward tokens which may or may not be on vesting schedules to claim
    // single rewards has an index [UNI, OP, SNX] within that index there are sub arrays of vesting schedule
    // base rewards there is only a sub array of vesting schedules
    function claimableTokens(
        uint256 _tokenId,
        ClaimType _claimType,
        uint8 _vestingScheduleIndex,
        uint8 _singleRewardsIndex
    ) public view returns (uint256) {
        if (lpDepositTime == 0) {
            return 0;
        }
        // struct VestVestingToken {
        //     uint256 amountDeposited;
        //     uint256 lastClaimedAt;
        //     uint256[] lastClaimedAtRewardList;
        //     uint8 vestingScheduleIndex;
        // }
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedClaimable;

        uint256 lastClaimedAt = _claimType == ClaimType.Single
            ? schedule.lastClaimedAtRewardList[_singleRewardsIndex]
            : schedule.lastClaimedAt;

        // address rewardToken;
        // uint256 rewardTokenTotal;
        // SingleVestingSchedule[] vestingSchedules;
        // address singleHolder;
        // either going to read it off the singleRewards stu
        uint256 vestingCliffPeriod = _claimType == ClaimType.Single
            ? singleRewards[_singleRewardsIndex].vestingSchedules[schedule.vestingScheduleIndex].vestingCliffPeriod
            : vAmmInfo.vestingSchedules[schedule.vestingScheduleIndex].vestingCliffPeriod;

        uint256 vestingPeriod = _claimType == ClaimType.Single
            ? singleRewards[_singleRewardsIndex].vestingSchedules[schedule.vestingScheduleIndex].vestingPeriod
            : vAmmInfo.vestingSchedules[schedule.vestingScheduleIndex].vestingPeriod;

        uint256 vestingCliff = lpDepositTime + vestingCliffPeriod;
        uint256 vestingExpiry = vestingCliff + vestingPeriod;

        // claiming logic outline:
        // the logic for claiming is this you have the lpDepositWindow is when everything starts
        // then you have the vesting period cliff, then you have the vesting period.
        // you can start vesting at the end of the cliff
        // if the vesting period cliff is set to 0, you can start vesting right away.
        // if the vesting period is also 0 you can vest everything

    // struct SingleRewardConfig {
    //     address rewardToken;
    //     uint256 rewardTokenTotal;
    //     SingleVestingSchedule[] vestingSchedules;
    //     address singleHolder;
    // }
    // struct SingleVestingSchedule {
    //     VestingSchedule vestingSchedule;
    //     uint8 vestingScheduleIndex;
    //     uint256 totalTokens;
    // }

        uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        uint256 minTime = block.timestamp < lpDepositTime ? lpDepositTime : block.timestamp;

        if (lastClaimedAt < maxTime) {
            // uint8 investmentTokenDecimals = IERC20Decimals(ammData.investmentToken).decimals();
            uint256 tokensClaimable = _claimType == ClaimType.Single
                ? singleRewards[_singleRewardsIndex].schedules[schedule.vestingScheduleIndex]. ((schedule.amountDeposited) / depositedPerVestSchedule[_vestingScheduleIndex]) // 10% of the bucket *
                    ((maxTime - minTime) / vestingPeriod) // 50% of the vesting period
                : 0;

            // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
            // although it will generally never happen as solidity rounds down so there should always be a little bit left
            precisionAdjustedClaimable = tokensClaimable > IERC20(lpToken).balanceOf(address(this))
                ? IERC20(lpToken).balanceOf(address(this))
                : tokensClaimable;
        } else if (maxTime == minTime && vestingPeriod == 0) {}
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
        _claimTokens(_tokenId, ClaimType.LP, 0);
    }

    /**
     * @dev allows a user to claim their single sided reward tokens or a partial amount
     * of their single sided reward tokens once they have vested according to the schedule
     */
    function claimRewardToken(uint256 _tokenId, uint256 _claimIndex) external {
        _claimTokens(_tokenId, ClaimType.Single, _claimIndex);
    }

    function _claimTokens(
        uint256 _tokenId,
        ClaimType _claimType,
        uint256 _claimIndex
    ) internal {
        require(ownerOf(_tokenId) == msg.sender, "must be owner to claim");
        // TODO double check this doesn't error if there are no single sided rewards
        uint256 claimableAmount = claimableTokens(_tokenId, _claimType, _claimIndex);
        require(claimableAmount > 0, "no lp tokens ready to claim");
        if (_claimType == ClaimType.LP) {
            vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
            totalLPClaimed += claimableAmount;
        } else {
            vestingDetails[_tokenId].lastClaimedAtRewardList[_claimIndex] = block.timestamp;
            // TODO like we do for the LP positions, track totals for each single reward type claimed
            // in a mapping we can query from UI
        }
        // VestAMMMultiRewards.withdraw(depositTokenAmount);
        address claimToken = _claimType == ClaimType.LP ? lpToken : singleRewards[_claimIndex].token;
        IERC20(claimToken).safeTransfer(msg.sender, claimableAmount);
        emit ClaimedToken(claimToken, msg.sender, claimableAmount, _claimType);
    }

    function sendFeesToAelin(address _token, uint256 _amount) external {
        IERC20(_token).approve(aelinFeeModule, _amount);
        AelinFeeModule(aelinFeeModule).sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    // NOTE that each single rewards will have multiple vesting schedules for each
    function _validateAddSingle(SingleRewardConfig[] _singleRewards) internal {
        require(_singleRewards.length + singleRewards.length <= MAX_SINGLE_REWARDS, "too many single-sided rewards");
        for (uint256 i; i < _singleRewards.length; i++) {
            require(_singleRewards[i].rewardToken != address(0), "cannot pass null address");
            require(_singleRewards[i].singleHolder != address(0), "cannot pass null address");
            require(_singleRewards[i].rewardTokenTotal > 0, "rtt: must pass an amount");
            SingleVestingSchedule[] vestingSchedules = _singleRewards.vestingSchedules;
            _validateSingleVesting(vestingSchedules);
        }
        for (uint i = 0; i < _singleRewards.length; i++) {
            singleRewards[singleRewards.length + i] = _singleRewards[i];
        }
    }

    function _validateSchedules(LPVestingSchedule[] _vestingSchedules) internal {
        require(_vestingSchedules.length <= MAX_LP_VESTING_SCHEDULES, "too many vesting periods");
        for (uint256 i; i < _vestingSchedules.length; ++i) {
            require(1825 days >= _vestingSchedules[i].schedule.vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _vestingSchedules[i].schedule.vestingPeriod, "max 5 year vesting");
            require(0 < _vestingSchedules[i].totalTokens, "allocate tokens to schedule");
            require(0 == _vestingSchedules[i].claimed, "claimed must start at 0");
            require(100 * 10**18 >= _vestingSchedules[i].investorLPShare, "max 100% to investor");
            require(0 <= _vestingSchedules[i].investorLPShare, "min 0% to investor");
            _validateSingleVestingSched(_vestingSchedules[i].singleVestingSchedules);
        }
    }

    function _validateSingleVestingSched(SingleVestingSchedule[] _singleVestingSchedules) internal {
        for (uint256 i; i < _singleVestingSchedules.length; ++i) {
            require(1825 days >= _singleVestingSchedules[i].vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _singleVestingSchedules[i].vestingPeriod, "max 5 year vesting");

            require(_singleVestingSchedules[i].totalTokens > 0, "need tokens as rewards");
            require(_singleVestingSchedules[i].claimed == 0, "amount claimed must be 0");
            require(_singleVestingSchedules[i].singleHolder != address(0), "cant pass null address");
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
    function mintVestingToken(
        address _to,
        uint256 _amount,
        uint8 _vestingScheduleIndex
    ) internal {
        mintVestingToken(msg.sender, depositTokenAmount, _vestingScheduleIndex);
        // NOTE there is maybe a better way to do this
        uint256[] singleRewardTimestamps;
        for (uint i = 0; i < singleRewards.length; i++) {
            singleRewardTimestamps[i] = depositExpiry;
        }
        // we have to track up to 11 vesting schedules in a single NFT
        singleRewards[_singleRewards[i].singleHolder][_singleRewards[i].rewardToken] = _singleRewards[i];
        // we need to track when you claimed each single sided reward separately
        // and also when you last claimed the base asset
        // [ts1, ts2, ts3, ts4]
        // ts1 tied to singleRewards[0]
        // singleRewards[_singleRewards[i].singleHolder][_singleRewards[i].rewardToken] = _singleRewards[i];
        _mintVestingToken(_to, _amount, depositExpiry, singleRewardTimestamps, _vestingScheduleIndex);
    }

    function singleRewardsToDeposit(address _holder) external view returns(rewardsToDeposit) {
        DepositToken[] rewardsToDeposit;
        for (uint i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            for (uint j = 0; j < vAmmInfo.lpVestingSchedules[i].singleVestingSchedules; j++) {
                if (_holder == vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].singleHolder) {
                    rewardsToDeposit.push(
                        DepositToken(
                            i,
                            j,
                            vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].rewardToken,
                            // TODO reduce this by the amount that has already been deposited 
                            vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].totalTokens
                        )
                    );
                }
            }
        }
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
        require(isCancelled || (lpDepositTime == 0 && block.timestamp > lpFundingExpiry), "deal not cancelled");
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

    modifier vestingScheduleOpen(uint8 _vestingScheduleIndex, uint256 _investmentTokenAmount) {
        bool otherBucketsFull = true;
        for (uint8 i; i < numVestingSchedules.length; i++) {
            if (i == _vestingScheduleIndex) {
                continue;
            }
            if (!isVestingScheduleFull[numVestingSchedules[i]]) {
                otherBucketsFull = false;
                break;
            }
        }
        require(
            depositedPerVestSchedule[_vestingScheduleIndex] + _investmentTokenAmount <=
                maxInvTokensPerVestSchedule[_vestingScheduleIndex] ||
                (otherBucketsFull && vAmmInfo.deallocation == Deallocation.Proportional),
            "purchased more than total"
        );
        _;
    }

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }
}
