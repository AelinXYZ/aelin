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

import "contracts/libraries/validation/VestAMMValidation.sol";

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

    //  - we create the pool with the given ratios and tokens (only for liquidity launch)
    //  - we deposit the LP tokens
    //  - we have to track the amount of tokens we deposited vs the amount we allocated per main bucket (up to 4)

    uint256 constant BASE = 100 * 10**18;
    uint256 constant VEST_ASSET_FEE = 1 * 10**18;
    uint256 constant VEST_SWAP_FEE = 20 * 10**18;
    uint256 public depositExpiry;
    uint256 public lpFundingExpiry;
    uint256 public totalLPClaimed;
    uint256 public holderTokenTotal;
    uint256 public maxInvTokens;
    uint256 public amountBaseDeposited;
    uint8 private numVestingSchedules;
    mapping(uint8 => uint256) public maxInvTokensPerVestSchedule;
    mapping(uint8 => uint256) public depositedPerVestSchedule;
    mapping(uint8 => uint256) public lpClaimedPerVestSchedule;
    mapping(uint8 => mapping(uint8 => uint256)) public singleClaimedPerVestSchedule;
    mapping(address => uint256) totalSingleClaimed;
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
    DepositData public depositData;

    uint256 public globalTotalLPTokens;

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
            Validate.poolExists(_ammData.ammLibrary.checkPoolExists(ammData), ammData.poolAddress); // NOTE: Check if poolAddress is required if hasLaunchPhase is false
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

        Validate.allowListAndNftListNotAllowed(nftGating.hasNftList && _dealAccess.merkleRoot != 0);
        Validate.allowListAndMerkleNotAllowed(allowList.hasAllowList && nftGating.hasNftList);
        Validate.nftListAndMerkleNotAllowed(nftGating.hasNftList && _dealAccess.merkleRoot != 0);
        Validate.hasIPFSHash(bytes(_dealAccess.ipfsHash).length == 0 && _dealAccess.merkleRoot != 0);
    }

    function setDepositComplete() internal {
        if (baseComplete == true && singleRewardsComplete == numSingleRewards) {
            depositComplete = true;
            depositExpiry = block.timestamp + vAmmInfo.depositWindow;
            lpFundingExpiry = depositExpiry + vAmmInfo.lpFundingWindow;
            emit DepositComplete(depositExpiry, lpFundingExpiry);
        }
    }

    function depositSingle(DepositToken[] calldata _depositTokens) external depositIncomplete dealOpen {
        for (uint i = 0; i < _depositTokens.length; i++) {
            SingleVestingSchedule singleVestingSchedule = vAmmInfo
                .lpVestingSchedules[_depositTokens[i].vestingScheduleIndex]
                .singleVestingSchedules[_depositTokens[i].singleRewardIndex];
            Validate.singleHolder(vAmmInfo.mainHolder, singleVestingSchedule.singleHolder, i);
            Validate.singleToken(_depositTokens[i].token, singleVestingSchedule.rewardToken, i);
            Valida.singleTokenBalance(_depositTokens[i].amount, IERC20(_depositTokens[i].token).balanceOf(msg.sender), i);
            Validate.signleDepositNotFinalized(singleVestingSchedule.finalizedDeposit, i);

            // check deposit is not finalized here
            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;

            holderDeposits[msg.sender][_depositTokens[i].vestingScheduleIndex][
                _depositTokens[i].singleRewardIndex
            ] += amountPostTransfer;

            emit SingleRewardDeposited(
                msg.sender,
                _depositTokens[i].vestingScheduleIndex,
                _depositTokens[i].singleRewardIndex,
                _depositTokens[i].token,
                amountPostTransfer
            );
            if (
                holderDeposits[msg.sender][_depositTokens[i].vestingScheduleIndex][_depositTokens[i].singleRewardIndex] >=
                singleVestingSchedule.totalSingleTokens
            ) {
                singleRewardsComplete += 1;
                singleVestingSchedule.finalizedDeposit = true;
                emit SingleDepositComplete(
                    _depositTokens[i].token,
                    _depositTokens[i].vestingScheduleIndex,
                    _depositTokens[i].singleRewardIndex
                );
            }
        }
        setDepositComplete();
    }

    function cancelAndRefundVestAMM() external onlyHolder depositIncomplete {
        for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            for (uint8 j = 0; j < vAmmInfo.lpVestingSchedules[i].singleVestingSchedules; j++) {
                removeSingle(RemoveSingle(i, j, vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].token));
            }
        }
        if (amountBaseDeposited > 0) {
            IERC20(baseAsset).safeTransferFrom(address(this), vAmmInfo.mainHolder, amountBaseDeposited);
        }
        cancelVestAMM();
    }

    function cancelVestAMM() external onlyHolder depositIncomplete {
        isCancelled = true;
    }

    function addSingle(uint256[] calldata _lpVestingIndexList, SingleVestingSchedule[] calldata _newSingleRewards)
        external
        onlyHolder
        depositIncomplete
        dealOpen
    {
        Validate.lpVestingAndSingleArrayLength(_lpVestingIndexList.length, _newSingleRewards.length);
        _validateSingleVestingSched(_newSingleRewards);
        for (uint8 i = 0; i < _lpVestingIndexList.length; i++) {
            LPVestingSchedule lpVestingSchedule = vAmmInfo.lpVestingSchedules[_lpVestingIndexList[i]];
            Validae.maxSingleRewards(MAX_SINGLE_REWARDS, lpVestingSchedule.singleVestingSchedules.length, i);
            lpVestingSchedule.singleVestingSchedules[lpVestingSchedule.singleVestingSchedules.length] = _newSingleRewards[i];
        }
    }

    function removeSingle(RemoveSingle[] calldata _removeSingleList) external depositIncomplete {
        for (uint8 i = 0; i < _removeSingleList.length; i++) {
            LPVestingSchedule lpVestingSchedule = vAmmInfo.lpVestingSchedules[_removeSingleList[i].vestingScheduleIndex];
            SingleVestingSchedule singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[
                _removeSingleList[i].singleRewardIndex
            ];
            Validate.singleHolder(vAmmInfo.mainHolder, singleVestingSchedule.singleHolder, i);
            uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][_removeSingleList[i].vestingScheduleIndex][
                _removeSingleList[i].singleRewardIndex
            ];
            uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][
                _removeSingleList[i].vestingScheduleIndex
            ][_removeSingleList[i].singleRewardIndex];
            if (mainHolderAmount > 0) {
                IERC20(singleRewards[_removeSingleList[i]].token).safeTransferFrom(
                    address(this),
                    vAmmInfo.mainHolder,
                    mainHolderAmount
                );
            }
            if (singleHolderAmount > 0) {
                IERC20(singleRewards[_removeSingleList[i]].token).safeTransferFrom(
                    address(this),
                    singleRewards[_removeSingleList[i]].singleHolder,
                    singleHolderAmount
                );
            }
            emit SingleRemoved(
                _removeSingleList[i].singleRewardIndex,
                _removeSingleList[i].vestingScheduleIndex,
                singleRewards[_removeSingleList[i]].token,
                singleRewards[_removeSingleList[i]].rewardTokenTotal,
                mainHolderAmount,
                singleHolderAmount
            );

            if (singleVestingSchedule.finalizedDeposit) {
                singleRewardsComplete -= 1;
            }

            if (_removeSingleList[i].singleRewardIndex != lpVestingSchedule.singleVestingSchedules.length - 1) {
                lpVestingSchedule.singleVestingSchedules[_removeSingleList[i].singleRewardIndex] = lpVestingSchedule
                    .singleVestingSchedules[lpVestingSchedule.singleVestingSchedules.length - 1];
                holderDeposits[vAmmInfo.mainHolder][_removeSingleList[i].vestingScheduleIndex][
                    _removeSingleList[i].singleRewardIndex
                ] = holderDeposits[vAmmInfo.mainHolder][_removeSingleList[i].vestingScheduleIndex][
                    lpVestingSchedule.singleVestingSchedules.length - 1
                ];
                holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList[i].vestingScheduleIndex][
                    _removeSingleList[i].singleRewardIndex
                ] = holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList[i].vestingScheduleIndex][
                    lpVestingSchedule.singleVestingSchedules.length - 1
                ];
            }
            delete lpVestingSchedule.singleVestingSchedules[lpVestingSchedule.singleVestingSchedules.length - 1];
            delete holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList[i].vestingScheduleIndex][
                lpVestingSchedule.singleVestingSchedules.length - 1
            ];
            delete holderDeposits[vAmmInfo.mainHolder][_removeSingleList[i].vestingScheduleIndex][
                lpVestingSchedule.singleVestingSchedules.length - 1
            ];
        }
    }

    function depositBase() external onlyHolder depositIncomplete dealOpen {
        Validate.baseDepositNotCompleted(baseComplete);
        address baseAsset = ammData.baseAsset;

        uint256 balanceBeforeTransfer = IERC20(baseAsset).balanceOf(address(this));
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), holderTokenTotal);
        uint256 balanceAfterTransfer = IERC20(baseAsset).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        amountBaseDeposited += amountPostTransfer;
        emit DepositPoolToken(baseAsset, msg.sender, amountPostTransfer);
        if (amountBaseDeposited >= holderTokenTotal) {
            baseComplete = true;
        }

        setDepositComplete();
    }

    // TODO make sure the timestamp restrictions are set properly on these methods
    function withdrawAllExcessFunding() external {
        for (uint i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            withdrawExcessFunding(i);
        }
    }

    // TODO make each holder withdraw their own separately or keep it like this???
    function withdrawExcessFunding(uint256 _vestingScheduleIndex) external lpComplete {
        LPVestingSchedule lpVestingSchedule = vAmmInfo.vestingSchedules[schedule.vestingScheduleIndex];
        uint256 excessBaseAmount = lpVestingSchedule.totalBaseTokens -
            ((lpVestingSchedule.totalBaseTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
                maxInvTokensPerVestSchedule[_vestingScheduleIndex]);
        IERC20(ammData.baseAsset).safeTransferFrom(address(this), vAmmInfo.holder, excessBaseAmount);

        for (uint i = 0; i < lpVestingSchedule.singleVestingSchedules.length; i++) {
            SingleVestingSchedule singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[i];
            Validate.singleHolder(vAmmInfo.mainHolder, singleVestingSchedule.singleHolder, i);

            uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][_vestingScheduleIndex][i];
            uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][_vestingScheduleIndex][i];

            uint256 excessAmount = singleVestingSchedule.totalSingleTokens -
                ((singleVestingSchedule.totalSingleTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
                    maxInvTokensPerVestSchedule[_vestingScheduleIndex]);
            // TODO be careful of precision errors here
            uint256 excessAmountMain = (excessAmount * mainHolderAmount) / (mainHolderAmount + singleHolderAmount);
            uint256 excessAmountSingle = (excessAmount * singleHolderAmount) / (mainHolderAmount + singleHolderAmount);
            IERC20(singleRewards[_singleIndex].token).safeTransferFrom(address(this), vAmmInfo.mainHolder, excessAmountMain);
            IERC20(singleRewards[_singleIndex].token).safeTransferFrom(
                address(this),
                singleVestingSchedule.singleHolder,
                excessAmountSingle
            );
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
        Validate.vestingScheduleExists(!!vAmmInfo.vestingSchedule[_vestingScheduleIndex], _vestingScheduleIndex);
        Validate.investmentTokenBalance(_investmentTokenAmount, IERC20(ammContract.investmentToken).balanceOf(msg.sender));
        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _investmentTokenAmount);
        } else if (allowList.hasAllowList) {
            Validate.allocation(allowList.amountPerAddress[msg.sender], _investmentTokenAmount);
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

    // phase 0 is deposit all tokens from holders (no deadlines). mostly done
    // phase 1 is deposit investment tokens from depositors (deposit expiry). mostly done
    // phase 2 is deposit LP tokens to finalize the deal. TODO.
    // phase 2 NOTE: Liquidity Launch Pools and Liquidity Growth Pools
    //
    //  - we create the pool with the given ratios and tokens (only for liquidity launch)
    //  - we deposit the LP tokens
    //  - we set the amount of LP tokens deposited
    //  - we set the time when the LP tokens were deposited
    //
    //  - e.g.you have 3 buckets with 10, 20 and 30 ABC tokens each with longer vesting schedules than the previous bucket
    //    in addition to the ABC there is OP single sided rewards of 10, 20 and 30 for each bucket as well
    //    ABC is raising at a price of 10 sUSD so you have 100 sUSD, 200 sUSD and 300 sUSD as the max amount of investment tokens per bucket
    //    so if bucket 1 only fills up 50%, bucket 2 fills up 75% and bucket 3 fills to the cap
    //    assuming this is a liquidity launch for ABC then the logic is when we go to deposit LP tokens
    //    first we will create the pool, then we will deposit 5 ABC (50% * 10) from bucket 1, 15 ABC from bucket 2 (75% * 20), and 30 ABC from bucket 3 (100% * 30)
    //    in total this is 5 + 15 + 30 = 50 AELIN. and we also raised 500 sUSD. so we are going to LP 50 AELIN/500 sUSD and we need to
    //    note the address of the LP tokens we get back as well as how many LP tokens we get back and the time when we deposited (save to storage)
    //
    //  - the more complicated phase is a liquidity growth phase
    //  - in this growth phase the prices are shifting
    //  - price at start of pool is 10 sUSD per ABC
    //  - e.g.you have 3 buckets with 10, 20 and 30 ABC tokens each fills up 50%, 75%, and 100% based on the price at the start of the pool
    //  - the price of ABC between the start of the pool and the time we LP is irrelevant.
    //  - we only care about the price when the pool starts as well as the price when we go to LP
    //  - if the price of ABC goes down to $5 then...
    //    - the maximum amount of sUSD we can accept is $50, $100, $150
    //    - but there is $50, $150 and $300 in each bucket. this was the maximum amount based on the starting price
    //    - 2 issues. first
    //    - NOTE: since the price went down investors are happy because they get more ABC tokens for the same amount of sUSD
    //    - NOTE we might want to let the protocol deposit extra tokens on their side in order to use the full amount of sUSD
    //      - for bucket 1 if the price is 5 sUSD now even though the price was $10 and we only filled up half the pool we
    //      - actually have enough ABC to match all the sUSD now 50 sUSD/ 10 ABC. now the investors get double the amount of ABC. there is no problem
    //      - for bucket 3 if the price 5 sUSD the total 300/ 60 ABC is the max but we only have 30 ABC in the contract.
    //      - ideally the protocol can decide to deposit an extra 30 ABC here or we can force them to only take half the sUSD and return the rest
    //      - option 1 is you take 150/30 or you add more ABC and do 300/60. TBD
    //  - if the price of ABC stays flat at $10 then the logic is exact same as a liquidity launch (will basically never happen)...
    //    - the maximum amount of sUSD we can accept is $100, $200, $300
    //  - if the price of ABC goes up to $20 then...
    //    - the maximum amount of sUSD we can accept is $100, $200, $300
    //    - however the amounts in the pool are $50, $150 and $300
    //    - for bucket 1 we want to LP (50 sUSD/ 2.5 ABC).
    //         if the price was $10 the investors would have had more ABC in their LP. 50 sUSD/ 5 ABC
    //         so they will get at least 5 ABC tokens as a reward (LP or single sided)
    //         however when the price goes up they get less than 5 ABC. so we give them the extra as single sided rewards
    //         the math for this is:
    //         total allocation to bucket 1 (10 ABC) - (percent of bucket 1 empty (50%) * total allocation to bucket 1 (10 ABC)) = 10 - 5 = 5 ABC - the amount of ABC in the LP (2.5) = 5 - 2.5 = 2.5 AELIN single sided rewards
    //         2.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
    //    - for bucket 2 we want to LP (150 sUSD/ 7.5 ABC).
    //         if the price was $10 the investors would have had more ABC in their LP. 150 sUSD/ 15 ABC
    //         so they will get at least 15 ABC tokens as a reward (LP or single sided) and 5 ABC tokens are going back to the protocol
    //         however when the price goes up they get less than 15 ABC. so we give them the extra as single sided rewards
    //         the math for this is:
    //         total allocation to bucket 2 (20 ABC) - (percent of bucket 1 empty (25%) * total allocation to bucket 1 (20 ABC)) = 20 - 5 = 15 ABC - the amount of ABC in the LP (7.5) = 15 - 7.5 = 7.5 AELIN single sided rewards
    //         7.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
    //    - for bucket 3 we want to LP (300 sUSD/ 15 ABC).
    //         if the price was $10 the investors would have had more ABC in their LP. 300 sUSD/ 30 ABC
    //         so they will get at least 30 ABC tokens as a reward (LP or single sided) and 0 ABC tokens are going back to the protocol since the bucket is full
    //         however when the price goes up they get less than 30 ABC. so we give them the extra as single sided rewards
    //         the math for this is:
    //         total allocation to bucket 3 (30 ABC) - (percent of bucket 1 empty (0%) * total allocation to bucket 1 (30 ABC)) = 30 - 0 = 30 ABC - the amount of ABC in the LP (15) = 30 - 15 = 15 AELIN single sided rewards
    //         7.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
    // phase 3 is just claiming. mostly done
    // also phase 3/ phase 4 is VestAMMMultiRewards.sol where only the mainHolder can emit new rewards to locked LPs. TODO.
    // to create the pool and deposit assets after phase 0 ends
    // TODO create a struct here that should cover every AMM. If needed to support more add a second struct
    function createInitialLiquidity() external onlyHolder lpFundingWindow {
        validate.isLiquidityLaunch(vAmmInfo.hasLiquidityLaunch);
        // NOTE here are the steps that need to happen in a liquidity launch step by step
        // first you create the pool (in library)
        // then you deposit the right amount of (sUSD/ABC). the price is fixed
        // so its all the protocol tokens or just as much as can be paired against the number of investment tokens
        // across all buckets or the total amount deposited, whichever is smaller
        // we need to capture what the LP token that we used is and save the address and amount of LP tokens we get back
        // we also need to capture the timestamp of the block when we LP'd
        // NOTE that we need to figure out within each bucket if the bucket is not full
        // then we need to refund the single sided rewards and protocol tokens for that bucket based on how much was not filled
        // e.g. bucket 1 is 100 ABC and the price is 10 sUSD totalling 1000 sUSD
        // but the bucket only gets 600 sUSD instead of 1000, then each holder gets back 40%
        // deploy pool needs to create the pool and deposit the LP tokens and it needs to give us back a few things
        // TODO fix the first argument to use a new variable that combines the fields we have already stored related to the pool
        DeployPool deployPool = createDeployPool();
        IVestAMMLibrary(ammData.ammLibrary).deployPool(deployPool, depositData);
        // TODO stop using this twice. we can refactor
        uint256 totalInvestmentTokenAmount = totalDeposited < maxInvTokens ? totalDeposited : maxInvTokens;
        for (uint i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            uint256 scheduleInvestmentTotal = depositedPerVestSchedule[i] > maxInvTokensPerVestSchedule[i]
                ? maxInvTokensPerVestSchedule[i]
                : depositedPerVestSchedule[i];
            lpTokenAmountPerSchedule[i] = (depositData.lpTokenAmount * scheduleInvestmentTotal) / totalInvestmentTokenAmount;
        }
        finalizeVesting();
    }

    function createDeployPool() internal returns (DeployPool) {
        // TODO add in the other variables needed to deploy a pool and return these values
        uint256 investmentTokenAmount = totalDeposited < maxInvTokens ? totalDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalDeposited < maxInvTokens
            ? (holderTokenTotal * totalDeposited) / maxInvTokens
            : holderTokenTotal;

        return DeployPool(investmentTokenAmount, baseTokenAmount);
    }

    // to create the pool and deposit assets after phase 0 ends
    function createLiquidity(IBalancerPool.AddLiquidity _addLiquidity) external onlyHolder lpFundingWindow {
        Validate.notLiquidityLaunch(vAmmInfo.hasLiquidityLaunch);
        // liquidity growth is going to be more complex than liquidity launch since the price will shift
        // the pool has already been created so no need for that first
        // first we need to determine if the price ratio between the two assets have changed since we
        // created the vAMM. we read this initial price off the pool in the initialize function
        // if the price goes up, down or stays the same the logic will change
        // 1. if the price stays the same
        // we need to capture what the LP token that we used is and save the address and amount of LP tokens we get back
        // we also need to capture the timestamp of the block when we LP'd
        // NOTE that we need to figure out within each bucket if the bucket is not full
        // then we need to refund the single sided rewards and protocol tokens for that bucket based on how much was not filled
        // 2. if the price goes up
        // we need to LP the maximum amount of ABC tokens that we can against the available investment tokens
        // whatever is left of ABC tokens in a given bucket over needs to be given as single sided rewards to that
        // specific bucket NOTE that if a bucket is not full we need to also make sure the protocol can take their tokens
        // back and only the portion of the extra will be given as single sided rewards. we need some math for this.
        // basically we take how many protocol tokens you would get if the price never shifted to see what amount goes
        // back to the protocol and what amount goes to single sided rewards.
        // 3. if the price goes down
        // we need to add a view that tells the holder how many extra tokens they can deposit to make up for the difference
        // they can invest from 0 extra up to that full amount. this gives the sUSD investors more ABC tokens vs the price
        // at initilization.
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
        Validate.withdrawAllowed(_depositComplete, _lpFundingExpiry);
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

    function claimableTokens(
        uint256 _tokenId,
        ClaimType _claimType,
        uint8 _singleRewardsIndex
    ) public view returns (uint256) {
        if (lpDepositTime == 0) {
            return 0;
        }
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedClaimable;

        LPVestingSchedule lpVestingSchedule = vAmmInfo.vestingSchedules[schedule.vestingScheduleIndex];
        SingleVestingSchedule singleVestingSchedule;
        if (_claimType == ClaimType.Single) {
            singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[_singleRewardsIndex];
        }

        uint256 lastClaimedAt = _claimType == ClaimType.Single
            ? schedule.lastClaimedAtRewardList[_singleRewardsIndex]
            : schedule.lastClaimedAt;

        uint256 vestingCliffPeriod = _claimType == ClaimType.Single
            ? singleVestingSchedule.vestingCliffPeriod
            : lpVestingSchedule.vestingCliffPeriod;

        uint256 vestingPeriod = _claimType == ClaimType.Single
            ? singleVestingSchedule.vestingPeriod
            : lpVestingSchedule.vestingPeriod;

        uint256 vestingCliff = lpDepositTime + vestingCliffPeriod;
        uint256 vestingExpiry = vestingCliff + vestingPeriod;
        uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;

        if (lastClaimedAt < maxTime && block.timestamp > vestingCliff) {
            uint256 minTime = lastClaimedAt == 0 ? vestingCliff : lastClaimedAt;

            uint256 totalShare = _claimType == ClaimType.Single
                ? (((singleVestingSchedule.totalSingleTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
                    maxInvTokensPerVestSchedule[_vestingScheduleIndex]) * schedule.amountDeposited) /
                    depositedPerVestSchedule[schedule.vestingScheduleIndex]
                : (lpTokenAmountPerSchedule[schedule.vestingScheduleIndex] * schedule.amountDeposited) /
                    depositedPerVestSchedule[schedule.vestingScheduleIndex];

            uint256 claimableAmount = vestingPeriod == 0 ? totalShare : (totalShare * (maxTime - minTime)) / vestingPeriod;
            address claimToken = _claimType == ClaimType.Single ? singleVestingSchedule.token : depositData.lpToken;

            // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
            // although it will generally never happen as solidity rounds down so there should always be a little bit left
            precisionAdjustedClaimable = tokensClaimable > IERC20(claimToken).balanceOf(address(this))
                ? IERC20(claimToken).balanceOf(address(this))
                : tokensClaimable;
        }
        return precisionAdjustedClaimable;
    }

    /**
     * @dev allows a user to claim their all their vested tokens across a single NFT
     */
    function claimAllTokensSingleNFT(uint256 _tokenId) external {
        claimLPTokens(_tokenId);
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        LPVestingSchedule lpVestingSchedule = vAmmInfo.vestingSchedules[schedule.vestingScheduleIndex];
        for (uint256 i; i < lpVestingSchedule.singleVestingSchedules.length; i++) {
            claimRewardToken(_tokenId, i);
        }
    }

    /**
     * @dev allows a user to claim their all their vested tokens across many NFTs
     */
    function claimAllTokensManyNFTs(uint256[] _tokenIds) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            claimAllTokensSingleNFT(_tokenIds[i]);
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
    function claimRewardToken(uint256 _tokenId, uint256 _singleRewardsIndex) external {
        _claimTokens(_tokenId, ClaimType.Single, _singleRewardsIndex);
    }

    function _claimTokens(
        uint256 _tokenId,
        ClaimType _claimType,
        uint8 _singleRewardsIndex
    ) internal {
        Validate.owner(ownerOf(_tokenId));
        uint256 claimableAmount = claimableTokens(_tokenId, _claimType, _singleRewardsIndex);
        Validate.hasClaimBalance(claimableAmount);
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        address claimToken = _claimType == ClaimType.Single
            ? lpVestingSchedule.singleVestingSchedules[_singleRewardsIndex].token
            : depositData.lpToken;
        if (_claimType == ClaimType.Single) {
            vestingDetails[_tokenId].lastClaimedAtRewardList[_singleRewardsIndex] = block.timestamp;
            singleClaimedPerVestSchedule[schedule.vestingScheduleIndex][_singleRewardsIndex] += claimableAmount;
            totalSingleClaimed[claimToken] += claimableAmount;
        } else {
            vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
            totalLPClaimed += claimableAmount;
            lpClaimedPerVestSchedule[schedule.vestingScheduleIndex] += claimableAmount;
        }
        // TODO indicate to the VestAMMMultiRewards staking rewards contract that
        // a withdraw has occured and they now have less funds locked
        // VestAMMMultiRewards.withdraw(depositTokenAmount);
        IERC20(claimToken).safeTransfer(msg.sender, claimableAmount);
        emit ClaimedToken(
            claimToken,
            msg.sender,
            claimableAmount,
            _claimType,
            schedule.vestingScheduleIndex,
            _singleRewardsIndex
        );
    }

    function sendFeesToAelin(address _token, uint256 _amount) external {
        IERC20(_token).approve(aelinFeeModule, _amount);
        AelinFeeModule(aelinFeeModule).sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    function _validateSchedules(LPVestingSchedule[] _vestingSchedules) internal {
        Validate.maxVestingPeriods(MAX_LP_VESTING_SCHEDULES, _vestingSchedules.length);
        for (uint256 i; i < _vestingSchedules.length; ++i) {
            Validate.vestingCliff(1825 days, _vestingSchedules[i].schedule.vestingCliffPeriod, i);
            Validate.vestingPeriod(1825 days, _vestingSchedules[i].schedule.vestingPeriod, i);
            Validate.investorShare(100 * 10**18, 0, _vestingSchedules[i].investorLPShare, i);
            Validate.hasTotalBaseTokens(_vestingSchedules[i].totalBaseTokens, i);
            Validate.lpNotZero(_vestingSchedules[i].totalLPTokens, i);
            Validate.nothingClaimed(_vestingSchedules[i].claimed, i);
            Validate.maxSingleRewards(MAX_SINGLE_REWARDS, _vestingSchedules[i].singleVestingSchedules.length, i);
            _validateSingleVestingSched(_vestingSchedules[i].singleVestingSchedules);
        }
    }

    function _validateSingleVestingSched(SingleVestingSchedule[] _singleVestingSchedules) internal {
        for (uint256 i; i < _singleVestingSchedules.length; ++i) {
            Validate.singleVestingCliff(1825 days, _singleVestingSchedules[i].vestingCliffPeriod, i);
            Validate.singleVestingPeriod(1825 days, _singleVestingSchedules[i].vestingPeriod, i);
            Validate.hasTotalSingleTokens(_singleVestingSchedules[i].totalSingleToken, i);
            Validate.singleNothingClaimed(_singleVestingSchedules[i].claimed, i);
            Validate.singleHolderNotNull(_singleVestingSchedules[i].singleHolder, i);
            Validate.depositNotFinalized(_singleVestingSchedules[i].finalizedDeposit, i);
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
        uint256[] memory singleRewardTimestamps = new uint256[](
            vAmmInfo.lpVestingSchedules[_vestingScheduleIndex].singleVestingSchedules.length
        );
        _mintVestingToken(_to, _amount, 0, singleRewardTimestamps, _vestingScheduleIndex);
    }

    function singleRewardsToDeposit(address _holder) external view returns (rewardsToDeposit) {
        DepositToken[] rewardsToDeposit;
        for (uint i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            for (uint j = 0; j < vAmmInfo.lpVestingSchedules[i].singleVestingSchedules; j++) {
                address singleHolder = vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].singleHolder;
                if (_holder == vAmmInfo.mainHolder || _holder == singleHolder) {
                    uint256 amountDeposited = holderDeposits[vAmmInfo.mainHolder][i][j] + holderDeposits[singleHolder][i][j];
                    rewardsToDeposit.push(
                        DepositToken(
                            i,
                            j,
                            vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].rewardToken,
                            vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].totalTokens - amountDeposited
                        )
                    );
                }
            }
        }
    }

    modifier initOnce() {
        Validate.isNotInitialized(calledInitialize);
        calledInitialize = true;
        _;
    }

    modifier onlyHolder() {
        Validate.callerIsHolder(vAmmInfo.mainHolder, msg.sender);
        _;
    }

    modifier depositIncomplete() {
        Validate.depositIncomplete(depositComplete);
        _;
    }

    modifier dealOpen() {
        Validate.daelIsOpen(!isCancelled);
        _;
    }

    modifier dealCancelled() {
        Validate.isCancelled(isCancelled, lpDepositTime, lpFundingExpiry);
        _;
    }

    modifier lpFundingWindow() {
        Validate.inFundingWindow(isCancelled, depositComplete, depositExpiry, lpFundingExpiry);
        _;
    }

    // TODO add require. ty
    modifier lpComplete() {
        // require lpDepositTime > 0
        Validate.inFundingComplete(lpDepositTime);
        _;
    }

    modifier acceptDealOpen() {
        Validate.inDepositWindow(isCancelled, depositComplete, depositExpiry);
        // TODO double check < vs <= matches everywhere
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
        Validate.purchaseAmount(
            depositedPerVestSchedule[_vestingScheduleIndex],
            maxInvTokensPerVestSchedule[_vestingScheduleIndex],
            _investmentTokenAmount,
            otherBucketsFull,
            vAmmInfo.deallocation == Deallocation.Proportional
        );
        _;
    }

    modifier lock() {
        Validate.isUnlocked(locked);
        locked = true;
        _;
        locked = false;
    }
}
