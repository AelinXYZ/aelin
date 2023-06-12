// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "forge-std/console.sol";
// NEED pausing and management features
import "./VestVestingToken.sol";

// import "./VestAMMMultiRewards.sol";
import {AelinVestingToken} from "contracts/AelinVestingToken.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import "../libraries/MerkleTree.sol";
import "./interfaces/IVestAMM.sol";
import "./interfaces/IVestAMMLibrary.sol";

import "contracts/libraries/validation/VestAMMValidation.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract VestAMMMultiRewards {
    constructor(address _vestAMM) {}

    function stake(uint256 _amount) external {}

    function withdraw(uint256 _amount) external {}
}

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
    mapping(uint8 => uint256) public lpTokenAmountPerSchedule;
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

    // AmmData public ammData;
    VestAMMMultiRewards public vestAmmMultiRewards;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;

    bool private calledInitialize;
    bool private baseComplete;
    bool public isCancelled;
    bool public depositComplete;
    DepositData public depositData;

    uint256 public globalTotalLPTokens;

    IVestAMMLibrary internal vestAMMLibrary;

    uint256 public numInvTokensFee;
    uint256 public numBaseTokensFee;

    bool public locked = false;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        // AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess,
        address _aelinFeeModule
    ) external initOnce {
        _validateSchedules(_vAmmInfo.lpVestingSchedules);
        // pool initialization checks
        // TODO how to name these
        // _setNameAndSymbol(string(abi.encodePacked("vAMM-", TBD)), string(abi.encodePacked("v-", TBD)));
        // added ammData to VAmmInfo
        // ammData = _ammData;
        vAmmInfo = _vAmmInfo;
        dealAccess = _dealAccess;
        vestAMMLibrary = IVestAMMLibrary(_vAmmInfo.ammData.ammLibrary);
        // TODO
        // aelinFeeModule = _aelinFeeModule;

        // TODO work on the rewards logic
        // TODO research the limit of how many rewards tokens you can distribute
        // TODO emit the multi rewards distributor contract address
        // TODO
        // vestAmmMultiRewards = new VestAMMMultiRewards(address(this));

        // TODO if we are doing a liquidity growth round we need to read the prices of the assets
        // from onchain here and set the current price as the median price
        // TODO do a require check to make sure the pool exists if they are doing a liquidity growth
        // TODO research how to solve a new pool where liquidity exists elsewhere
        if (!_vAmmInfo.hasLaunchPhase) {
            // we need to pass in data to check if the pool exists. ammData is a placeholder but not the right argument
            Validate.poolExists(vestAMMLibrary.checkPoolExists(vAmmInfo)); // NOTE: Check if poolAddress is required if hasLaunchPhase is false
            // initial price ratio between the two assets
            // TODO slippage check
            investmentTokenPerBase = vestAMMLibrary.getPriceRatio(
                vAmmInfo.poolAddress,
                vAmmInfo.ammData.investmentToken,
                vAmmInfo.ammData.baseToken
            );
        }
        // TODO if its a launch make sure pool doesn't exist for certain AMMs
        // LP vesting schedule array up to 4 buckets
        // each bucket will have a token total in the protocol tokens
        // this loop calculates the maximum number of investment tokens that will be accepted
        // based on the price ratio at the time of creation or the price defined in the
        // launch struct for new protocols without liquidity
        uint256 invPerBase = _vAmmInfo.hasLaunchPhase ? _vAmmInfo.investmentPerBase : investmentTokenPerBase;

        numVestingSchedules = uint8(vAmmInfo.lpVestingSchedules.length);
        for (uint8 i = 0; i < numVestingSchedules; i++) {
            numSingleRewards += uint8(vAmmInfo.lpVestingSchedules[i].singleVestingSchedules.length);
            holderTokenTotal += vAmmInfo.lpVestingSchedules[i].totalBaseTokens;
            // the maximum number of investment tokens investors can deposit per vesting schedule
            // this is important for the deallocation logic and the ability to invest more than the cap
            // our logic for deallocation will be that all the schedules need to be full before you can
            // over allocate to any single bucket. BUT the protocol can choose to not allow deallocation
            // and only allow each bucket to fill up to the max
            // NOTE the invPerBase variable is in the investment token decimal format
            maxInvTokensPerVestSchedule[i] =
                (vAmmInfo.lpVestingSchedules[i].totalBaseTokens * invPerBase) /
                10**IERC20Decimals(vAmmInfo.ammData.baseToken).decimals();
            maxInvTokens += maxInvTokensPerVestSchedule[i];
        }

        // NOTE: We need to approve the lirbary to use base/investment tokens
        // instead of type(uint256).max we should use the max amount of tokens set by the user
        IERC20(vAmmInfo.ammData.baseToken).approve(address(vestAMMLibrary), type(uint256).max);
        IERC20(vAmmInfo.ammData.investmentToken).approve(address(vestAMMLibrary), type(uint256).max);

        // Allow list logic
        // check if there's allowlist and amounts,
        // if yes, store it to `allowList` and emit a single event with the addresses and amounts
        AelinAllowList.initialize(_dealAccess.allowListInit, allowList);

        // NftCollection logic
        // check if the deal is nft gated
        // if yes, store it in `nftCollectionDetails` and `nftId` and emit respective events for 721 and 1155
        AelinNftGating.initialize(_dealAccess.nftCollectionRules, nftGating);

        Validate.allowListAndNftListNotAllowed(!(allowList.hasAllowList && nftGating.hasNftList));
        Validate.allowListAndMerkleNotAllowed(!(allowList.hasAllowList && nftGating.hasNftList));
        Validate.nftListAndMerkleNotAllowed(!(nftGating.hasNftList && _dealAccess.merkleRoot != 0));
        Validate.merkleHasIPFSHash(!(bytes(_dealAccess.ipfsHash).length == 0 && _dealAccess.merkleRoot != 0));
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
            SingleVestingSchedule memory singleVestingSchedule = vAmmInfo
                .lpVestingSchedules[_depositTokens[i].lpScheduleIndex]
                .singleVestingSchedules[_depositTokens[i].singleRewardIndex];
            Validate.singleHolder(vAmmInfo.mainHolder == msg.sender || singleVestingSchedule.singleHolder == msg.sender);
            Validate.singleToken(_depositTokens[i].token == singleVestingSchedule.rewardToken);
            Validate.singleTokenBalance(_depositTokens[i].amount <= IERC20(_depositTokens[i].token).balanceOf(msg.sender));
            Validate.singleDepositNotFinalized(!singleVestingSchedule.finalizedDeposit);

            // check deposit is not finalized here
            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;

            holderDeposits[msg.sender][_depositTokens[i].lpScheduleIndex][
                _depositTokens[i].singleRewardIndex
            ] += amountPostTransfer;

            emit SingleRewardDeposited(
                msg.sender,
                _depositTokens[i].lpScheduleIndex,
                _depositTokens[i].singleRewardIndex,
                _depositTokens[i].token,
                amountPostTransfer
            );
            if (
                holderDeposits[msg.sender][_depositTokens[i].lpScheduleIndex][_depositTokens[i].singleRewardIndex] >=
                singleVestingSchedule.totalSingleTokens
            ) {
                singleRewardsComplete += 1;
                singleVestingSchedule.finalizedDeposit = true;
                emit SingleDepositComplete(
                    _depositTokens[i].token,
                    _depositTokens[i].lpScheduleIndex,
                    _depositTokens[i].singleRewardIndex
                );
            }
        }
        setDepositComplete();
    }

    // NOTE could this be a gas issue. Should we take in an array for this function so it can be
    // called multiple times so it doesn't need to do so much work at once.
    // there are up to 4 buckets and up to 6 rewards per bucket so could be 24 loops
    // TODO get rid of loops and pass in an array of vesting schedule and single rewards
    // NOTE this example below is more like javascript but shows the general idea
    // [{ 1: [1,2,3], 2: [2,3] }] by passing this in you are refunding the 1,2, and 3 index of single rewards for lp vesting bucket 1
    // as well as the 2 and 3 single reward index for vesting bucket 2. if someone wants to do all 24 at once they can just pass in the whole array
    function cancelAndRefundVestAMM() external onlyHolder depositIncomplete {
        // TODO maybe put this in another function like refundBase and the below logic can be in a method refundSingle or something
        // NOTE we are splitting this because removeSingle is complex and expensive to call
        if (amountBaseDeposited > 0) {
            IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, amountBaseDeposited);
        }

        for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            for (uint8 j = 0; j < vAmmInfo.lpVestingSchedules[i].singleVestingSchedules.length; j++) {
                RemoveSingle memory removeSingleData = RemoveSingle(
                    i,
                    j
                    // vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].rewardToken
                );
                removeSingle(removeSingleData);
            }
        }
        cancelVestAMM();
    }

    function cancelVestAMM() public onlyHolder depositIncomplete {
        isCancelled = true;
    }

    function addSingle(uint256[] calldata _lpVestingIndexList, SingleVestingSchedule[] calldata _newSingleRewards)
        external
        onlyHolder
        depositIncomplete
        dealOpen
    {
        // TODO: Validate _lpVestingIndexList indexes are valid ( ei: 99 => will revert)
        Validate.lpVestingAndSingleArrayLength(_lpVestingIndexList.length == _newSingleRewards.length);
        _validateSingleVestingSched(_newSingleRewards);
        for (uint8 i = 0; i < _lpVestingIndexList.length; i++) {
            Validate.maxSingleReward(
                MAX_SINGLE_REWARDS >= vAmmInfo.lpVestingSchedules[_lpVestingIndexList[i]].singleVestingSchedules.length
            );
            vAmmInfo.lpVestingSchedules[_lpVestingIndexList[i]].singleVestingSchedules.push(_newSingleRewards[i]);
            numSingleRewards += 1;
        }
    }

    function removeSingle(RemoveSingle memory _removeSingleList) public depositIncomplete {
        LPVestingSchedule memory lpVestingSchedule = vAmmInfo.lpVestingSchedules[_removeSingleList.lpScheduleIndex];
        SingleVestingSchedule memory singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[
            _removeSingleList.singleRewardIndex
        ];
        Validate.singleHolder(vAmmInfo.mainHolder == msg.sender || singleVestingSchedule.singleHolder == msg.sender);
        uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][_removeSingleList.lpScheduleIndex][
            _removeSingleList.singleRewardIndex
        ];
        uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList.lpScheduleIndex][
            _removeSingleList.singleRewardIndex
        ];
        if (mainHolderAmount > 0) {
            IERC20(singleVestingSchedule.rewardToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, mainHolderAmount);
        }
        if (singleHolderAmount > 0) {
            IERC20(singleVestingSchedule.rewardToken).safeTransferFrom(
                address(this),
                // singleRewards[_removeSingleList].singleHolder,
                singleVestingSchedule.singleHolder,
                singleHolderAmount
            );
        }
        emit SingleRemoved(
            _removeSingleList.singleRewardIndex,
            _removeSingleList.lpScheduleIndex,
            // singleRewards[_removeSingleList].token,
            // singleRewards[_removeSingleList].rewardTokenTotal,
            singleVestingSchedule.rewardToken,
            singleVestingSchedule.totalSingleTokens,
            mainHolderAmount,
            singleHolderAmount
        );

        if (singleVestingSchedule.finalizedDeposit) {
            singleRewardsComplete -= 1;
        }

        if (_removeSingleList.singleRewardIndex != lpVestingSchedule.singleVestingSchedules.length - 1) {
            lpVestingSchedule.singleVestingSchedules[_removeSingleList.singleRewardIndex] = lpVestingSchedule
                .singleVestingSchedules[lpVestingSchedule.singleVestingSchedules.length - 1];
            holderDeposits[vAmmInfo.mainHolder][_removeSingleList.lpScheduleIndex][
                _removeSingleList.singleRewardIndex
            ] = holderDeposits[vAmmInfo.mainHolder][_removeSingleList.lpScheduleIndex][
                uint8(lpVestingSchedule.singleVestingSchedules.length - 1)
            ];
            holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList.lpScheduleIndex][
                _removeSingleList.singleRewardIndex
            ] = holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList.lpScheduleIndex][
                uint8(lpVestingSchedule.singleVestingSchedules.length - 1)
            ];
        }
        delete lpVestingSchedule.singleVestingSchedules[lpVestingSchedule.singleVestingSchedules.length - 1];
        delete holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList.lpScheduleIndex][
            uint8(lpVestingSchedule.singleVestingSchedules.length - 1)
        ];
        delete holderDeposits[vAmmInfo.mainHolder][_removeSingleList.lpScheduleIndex][
            uint8(lpVestingSchedule.singleVestingSchedules.length - 1)
        ];

        // NOTE: was missing?
        numSingleRewards -= 1;
    }

    function removeSingles(RemoveSingle[] calldata _removeSingleList) external {
        for (uint8 i = 0; i < _removeSingleList.length; i++) {
            removeSingle(_removeSingleList[i]);
        }
    }

    function depositBase() external onlyHolder depositIncomplete dealOpen {
        Validate.baseDepositNotCompleted(!baseComplete);
        address baseToken = vAmmInfo.ammData.baseToken;

        // TODO add new validation for the base amount that they have enough
        Validate.baseTokenBalance(IERC20(baseToken).balanceOf(msg.sender) == holderTokenTotal);

        uint256 balanceBeforeTransfer = IERC20(baseToken).balanceOf(address(this));
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), holderTokenTotal);
        uint256 balanceAfterTransfer = IERC20(baseToken).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        amountBaseDeposited += amountPostTransfer;
        emit BaseDepositComplete(baseToken, msg.sender, amountPostTransfer);
        if (amountBaseDeposited >= holderTokenTotal) {
            baseComplete = true;
        }

        setDepositComplete();
    }

    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _investmentTokenAmount,
        uint8 _vestingScheduleIndex
    ) external lock acceptDealOpen vestingScheduleOpen(_vestingScheduleIndex, _investmentTokenAmount) {
        // TODO how to check if an array item is empty in solidity.
        // it says access to a non-existing index will throw an exception. lets test this.
        // TODO
        // Validate.vestingScheduleExists(vAmmInfo.lpVestingSchedules[_vestingScheduleIndex]);
        Validate.vestingScheduleExists(vAmmInfo.lpVestingSchedules.length >= _vestingScheduleIndex + 1);
        Validate.investmentTokenBalance(
            IERC20(vAmmInfo.ammData.investmentToken).balanceOf(msg.sender) >= _investmentTokenAmount
        );
        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _investmentTokenAmount);
        } else if (allowList.hasAllowList) {
            Validate.investorAllocation(allowList.amountPerAddress[msg.sender] >= _investmentTokenAmount);
            allowList.amountPerAddress[msg.sender] -= _investmentTokenAmount;
        } else if (dealAccess.merkleRoot != 0) {
            MerkleTree.purchaseMerkleAmount(_merkleData, trackClaimed, _investmentTokenAmount, dealAccess.merkleRoot);
        }
        uint256 balanceBeforeTransfer = IERC20(vAmmInfo.ammData.investmentToken).balanceOf(address(this));
        IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(msg.sender, address(this), _investmentTokenAmount);
        uint256 balanceAfterTransfer = IERC20(vAmmInfo.ammData.investmentToken).balanceOf(address(this));
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
        // stake your virtual token so the rewards distribution contract can track all the investors

        // TODO
        // VestAMMMultiRewards.stake(depositTokenAmount);
        // mintVestingToken(msg.sender, depositTokenAmount, _vestingScheduleIndex);

        emit AcceptVestDeal(msg.sender, depositTokenAmount, _vestingScheduleIndex);
    }

    function createInitialLiquidity() external onlyHolder lpFundingWindow {
        Validate.liquidityLaunch(vAmmInfo.hasLaunchPhase);

        // DeployPool memory deployPool = createDeployPool();
        address poolAddress = vestAMMLibrary.deployPool(vAmmInfo.newPoolData);
        // NOTE we can do this inside create add liquidity maybe instead where we calculate the fees
        // basically what we need is to determine exactly how much we are going to LP and then take out 1% for fees and track that
        IVestAMMLibrary.AddLiquidity memory addLiquidity = createAddLiquidity(poolAddress);
        // NOTE so imagine we have 100 ABC against 1000 sUSD that we are goign to LP into Balancer
        // in reality we are taking a 1% fee of these tokens before we LP. So we will end up LP'ing 99 ABC against 990 sUSD
        // and the fee will be 1 ABC against 10 sUSD
        // (numInvTokensInLP, numBaseTokensInLP, numInvTokensFee, numBaseTokensFee)
        (, , numInvTokensFee, numBaseTokensFee) = vestAMMLibrary.addInitialLiquidity(addLiquidity);
        saveDepositData(poolAddress);
        calcLPTokensPerSchedule();

        // TODO
        // aelinFees(numInvTokensFee, numBaseTokensFee);
    }

    // to create the pool and deposit assets after phase 0 ends
    // TODO add a view that calculates max extra base tokens and have a wrapper around that is called createLiquidityMax
    // which calls the view and passes in the max value to this method
    // function createLiquidity(uint256 _extraBaseTokens) external onlyHolder lpFundingWindow {
    //     Validate.notLiquidityLaunch(vAmmInfo.hasLiquidityLaunch);
    //     // If the price starts at 10 sUSD/ ABC and goes up to 20 sUSD per ABC then we need to add the extra ABC as single sided rewards
    //     // or if the price goes down to 5 sUSD / ABC we need to let the protocol add more tokens if they want
    //     uint256 currentRaio = ammData.ammLibrary.getPriceRatio(
    //         ammData.poolAddress,
    //         ammData.investmentToken,
    //         ammData.baseToken
    //     );
    //     LiquidityRatio liquidityRatio = createLiquidityRatio();
    //     (
    //         numInvTokensInLP, // example 1: 1000 sUSD (price up); example 2: 1000 sUSD (price down)
    //         numBaseTokensInLP, // example 1: 50 ABC (price up); example 2: 200 ABC (price down)
    //         initialNumInvTokensInLP, // 1000 sUSD
    //         initialNumBaseTokensInLP, // 100 ABC

    //     ) = IVestAMMLibrary(ammData.ammLibrary).getLiquidityRatios(liquidityRatio);
    //     // NOTE the initial price was 10 sUSD per ABC and the total in LP is 100 ABC to 1000 sUSD if the price doesn't change
    //     // NOTE if the price is the same then nothing changes and it should look just like a launch
    //     if (currentRatio > investmentTokenPerBase) {
    //         // NOTE the price has shifted to 20 sUSD per ABC
    //         // instead of doing 100 ABC to 1000 sUSD we are doing 50 ABC to 1000 sUSD
    //         // TODO add more single sided rewards from the base tokens
    //         uint256 excessTokens = initialNumBaseTokensInLP - numBaseTokensInLP;
    //         // TODO add another single sided reward with these amounts included spread across every vesting schedule
    //         // NOTE be wary of 2 things. we might have to track how full bucket is but maybe not. if you just put it in all the buckets
    //         // equally then the protocol can get their excess amount by calling withdrawExcessFunding
    //         // the other thing to be wary of is if we have the maximum number of single rewards we are going to add a 7th single sided reward
    //         // NOTE that we have to make sure that we override any maximum single rewards settings for this reward
    //         // NOTE might need a different function than addSingle() which shares most logic but allows you to add a 7th reward
    //         AddLiquidity addLiquidity = createAddLiquidity();
    //         (numInvTokensFee, numBaseTokensFee) = IVestAMMLibrary(ammData.ammLibrary).addLiquidity(addLiquidity);
    //         // and also allows you to add rewards this late in the process when all the rewards are already locked
    //     } else if (currentRatio < investmentTokenPerBase) {
    //         // NOTE the price has shifted to 5 sUSD per ABC. Now you get  200 - 100
    //         uint256 maxExcessBaseTokens = numBaseTokensInLP - initialNumBaseTokensInLP;
    //         // TODO add validation
    //         require(_excessBaseTokens <= maxExcessBaseTokens, "too many base tokens");
    //         Validate.baseTokenBalance(_excessBaseTokens, IERC20(baseToken).balanceOf(msg.sender));
    //         uint256 balanceBeforeTransfer = IERC20(baseToken).balanceOf(address(this));
    //         IERC20(baseToken).safeTransferFrom(msg.sender, address(this), _excessBaseTokens);
    //         uint256 balanceAfterTransfer = IERC20(baseToken).balanceOf(address(this));
    //         uint256 excessTransferred = balanceAfterTransfer - balanceBeforeTransfer;
    //         // NOTE when we create the new add liquidity struct

    //         // first we have to deposit those extra tokens and then we
    //         // create a new AddLiquidity struct but isntead of using amountBaseDeposited
    //         // we use amountBaseDeposited + excessTransferred and we LP with more ABC tokens
    //         AddLiquidity addLiquidity = createAddLiquidity();
    //         (numInvTokensFee, numBaseTokensFee) = IVestAMMLibrary(ammData.ammLibrary).addLiquidity(addLiquidity);
    //         // NOTE an important caveat is that when you add liquidity if they do not add enough excess tokens
    //         // then there will be excess sUSD that needs to be returned to investors. they will receive this amount
    //         // ideally by just calling the depositorDeallocWithdraw method when there is excess sUSD in a bucket
    //     }
    //     saveDepositData(ammData.poolAddress);
    //     calcLPTokensPerSchedule();
    //     aelinFees(numInvTokensFee, numBaseTokensFee);
    // }

    function saveDepositData(address _poolAddress) internal {
        // We might have to add a method to the librariers IVestAMMLibrary.balanceOf
        depositData = DepositData(_poolAddress, IERC20(_poolAddress).balanceOf(address(this)), block.timestamp);
    }

    // TODO review this logic
    function calcLPTokensPerSchedule() internal {
        uint256 totalInvestmentTokenAmount = totalDeposited < maxInvTokens ? totalDeposited : maxInvTokens;
        for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            uint256 scheduleInvestmentTotal = depositedPerVestSchedule[i] > maxInvTokensPerVestSchedule[i]
                ? maxInvTokensPerVestSchedule[i]
                : depositedPerVestSchedule[i];
            lpTokenAmountPerSchedule[i] = (depositData.lpTokenAmount * scheduleInvestmentTotal) / totalInvestmentTokenAmount;
        }
    }

    function createAddLiquidity(address _poolAddress) internal view returns (IVestAMMLibrary.AddLiquidity memory) {
        // TODO add in the other variables needed to deploy a pool and return these values
        uint256 investmentTokenAmount = totalDeposited < maxInvTokens ? totalDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalDeposited < maxInvTokens
            ? (holderTokenTotal * totalDeposited) / maxInvTokens
            : holderTokenTotal;

        uint256[] memory tokensAmtsIn = new uint256[](2);
        tokensAmtsIn[0] = investmentTokenAmount;
        tokensAmtsIn[1] = baseTokenAmount;

        address[] memory tokens = new address[](2);
        tokens[0] = vAmmInfo.ammData.investmentToken;
        tokens[1] = vAmmInfo.ammData.baseToken;

        return IVestAMMLibrary.AddLiquidity(_poolAddress, tokensAmtsIn, tokens);
    }

    // NOTE: Is this really needed?? I we only need this to add liquidity
    function createDeployPool() internal view returns (DeployPool memory) {
        // TODO add in the other variables needed to deploy a pool and return these values
        uint256 investmentTokenAmount = totalDeposited < maxInvTokens ? totalDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalDeposited < maxInvTokens
            ? (holderTokenTotal * totalDeposited) / maxInvTokens
            : holderTokenTotal;

        return DeployPool(investmentTokenAmount, baseTokenAmount);
    }

    // function aelinFees(uint256 _invTokenFeeAmt, uint256 _baseTokenFeeAmt) internal {
    //     sendFeesToAelin(ammData.baseToken, _baseTokenFeeAmt);
    //     sendFeesToAelin(ammData.investmentAsset, _baseTokenFeeAmt);

    //     // NOTE we need to DELETE or we just make it an admin call!!!! this part and figure out a more efficient way of sending single
    //     // sided rewards to the AelinFeeModule. In addition to 1% of the tokens used to LP (base + investment)
    //     // we are also taking 1% of each single sided reward
    //     // BUT instead of sending them all here which could be up to 24 transfers which happen at the end
    //     // of a lot of add liquidity logic
    //     // NOTE instead of sending the single fees here what we can do is when an investor goes to claim their rewards
    //     // we check if the fees have been sent yet and if not, we send the fees. So the first investor to claim any single
    //     // rewards tokens will also pay to transfer all the fees to Aelin. After that no one else has to pay.
    //     for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
    //         LPVestingSchedule lpVestingSchedule = vAmmInfo.lpVestingSchedules[i];
    //         for (uint8 j = 0; j < lpVestingSchedule.singleVestingSchedules.length; j++) {
    //             SingleVestingSchedule singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[j];

    //             uint256 singleRewardsUsed = ((singleVestingSchedule.totalSingleTokens *
    //                 depositedPerVestSchedule[_vestingScheduleIndex]) / maxInvTokensPerVestSchedule[_vestingScheduleIndex]);

    //             uint256 feeAmount = (singleRewardsUsed * VEST_ASSET_FEE) / 1e18;
    //             sendFeesToAelin(_singleRewards[i].token, feeAmount);
    //         }
    //     }
    // }

    // TODO make sure the timestamp restrictions are set properly on these methods
    function withdrawAllExcessFunding() external {
        for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            withdrawExcessFunding(i);
        }
    }

    // TODO make each holder withdraw their own separately or keep it like this???
    function withdrawExcessFunding(uint8 _vestingScheduleIndex) public lpComplete {
        LPVestingSchedule memory lpVestingSchedule = vAmmInfo.lpVestingSchedules[_vestingScheduleIndex];
        uint256 excessBaseAmount = lpVestingSchedule.totalBaseTokens -
            ((lpVestingSchedule.totalBaseTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
                maxInvTokensPerVestSchedule[_vestingScheduleIndex]);
        IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, excessBaseAmount);

        for (uint8 i = 0; i < lpVestingSchedule.singleVestingSchedules.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[i];
            Validate.singleHolder(vAmmInfo.mainHolder == msg.sender || singleVestingSchedule.singleHolder == msg.sender);

            uint256 mainHolderAmount = holderDeposits[vAmmInfo.mainHolder][_vestingScheduleIndex][i];
            uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][_vestingScheduleIndex][i];

            uint256 excessAmount = singleVestingSchedule.totalSingleTokens -
                ((singleVestingSchedule.totalSingleTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
                    maxInvTokensPerVestSchedule[_vestingScheduleIndex]);
            // TODO be careful of precision errors here
            uint256 excessAmountMain = (excessAmount * mainHolderAmount) / (mainHolderAmount + singleHolderAmount);
            uint256 excessAmountSingle = (excessAmount * singleHolderAmount) / (mainHolderAmount + singleHolderAmount);
            if (excessAmountMain > 0) {
                IERC20(singleVestingSchedule.rewardToken).safeTransferFrom(
                    address(this),
                    vAmmInfo.mainHolder,
                    excessAmountMain
                );
            }
            if (excessAmountSingle > 0) {
                IERC20(singleVestingSchedule.rewardToken).safeTransferFrom(
                    address(this),
                    singleVestingSchedule.singleHolder,
                    excessAmountSingle
                );
            }
        }
    }

    // for when the lp is not funded in time
    // function depositorWithdraw(uint256[] _tokenIds) external depositWindowEnded {
    //     for (uint256 i; i < _tokenIds.length; i++) {
    //         // NOTE make sure this properly tests ownership during testing
    //         Validate.owner(ownerOf(_tokenIds[i]));
    //         VestVestingToken memory schedule = vestingDetails[_tokenIds[i]];
    //         IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(address(this), msg.sender, schedule.amountDeposited);
    //         // NOTE any reason to burn the NFT?
    //         emit Withdraw(msg.sender, schedule.amountDeposited);
    //     }
    // }

    // withdraw deallocated
    // NOTE this function is when all the buckets are full and one or more
    // buckets have overflown. the excess amount in the bucket needs to be
    // proportionally returned to all investors in the pool. each investor
    // can reclaim their excess investment tokens by calling this method in that case
    // if the excess is too small it will be FCFS for the tiny amount of excess
    // NOTE we have to be very careful with precision and not to let them remove more than the
    // amount of excess in a bucket
    // function depositorDeallocWithdraw(uint256[] _tokenIds) external {
    //     Validate.withdrawAllowed(depositComplete, lpFundingExpiry);
    //     for (uint256 i; i < _tokenIds.length; i++) {
    //         VestVestingToken memory schedule = vestingDetails[_tokenId];
    //         // TODO need to calculate and save this number during LP submission
    //         // and store it as an 18 decimals percentage 5e17 is 50%
    //         uint256 deallocationPercent;
    //         uint256 excessWithdrawAmount = (schedule.amountDeposited * 1e18) / deallocationPercent;
    //         IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(address(this), msg.sender, excessWithdrawAmount);
    //         emit Withdraw(msg.sender, excessWithdrawAmount);
    //     }
    // }

    // collect the fees from AMMs and send them to the Fee Module
    function collectAllFees(uint256 tokenId) public returns (uint256 amount0, uint256 amount1) {
        // you have 50 LP tokens owned by our contract for one year
        // a few ways an AMM might implement swap fees.
        // method 1: they put the swap fees separate from the LP tokens
        // method 2: the underlying value of the LP tokens grows with the swap fees but you also get impermanent loss.
        // possible method 3: the number of LP tokens increase to 55 LP tokens
        // There 2 times when we want to capture fees
        // first instance is when someone goes to claim their LP tokens. Only when they are claiming LP tokens, not single sided rewards
        // second is we have a public function that anyone can call at any time to claim all the fees generated and to maybe reinvest the user fees if necessary
        //
        // what we need the library to do:
        // 1. be able to reinvest 80% of fees if the fees are held separate from the LP tokens
        // 2. calculate the number of fees generated since a specific point in time for a LP position
        // 3. remove the 20% of AELIN protocol fees from the LP position
        // NOTE outside of the library we will send fees that have been removed to the Aelin Fee Module
        //
        // we deposit the LP tokens and this contract owns them. what we need to do is have a method which calculates
        // how much in fees have been generated by the LP position since we last checked. we need to a) send 20% of these
        // fees to Aelin and b) reinvest the other 80% back into the LP position for locked LPs. Most AMMs will auto-reinvest
        // the fees but some like Uniswap and others will actually not auto reinvest. we will need to use the same libraries for each AMM
        // to handle the logic differently based on how they track fees.
        // To properly account for fees and take them there are a couple of things we need to do
        // when an investor goes to claim their tokens I dont think they should transfer fees, but we should have them
        // account for how many fees have been generated and set them aside
        // imagine we have 100 LP tokens with 10 ABC/ 100sUSD inside earning 20% interest annually.
        // so AELIN will take 4% = .2 * .2 of the fees and the investors will take the other 16% = .2 * .8
        // each time a person goes to claim they will make sure that 20% of ALL the fees generated are set aside for AELIN
        // in addition, they will make sure that the other fees are reinvested as necessary
        // Every once and a while there will be a public function that needs to be called in order to send fees to the Aelin Fee Module
        // alternatively we could make the users pay for the transfer
        // probably its ok to also have a public function that sends whatever fees have been accumulated to AELIN
        // NOTE will collect the fees and then call the method sendAelinFees(amounts...)
    }

    // function claimableTokens(
    //     uint256 _tokenId,
    //     ClaimType _claimType,
    //     uint8 _singleRewardsIndex
    // ) public view returns (uint256) {
    //     if (depositData.lpDepositTime == 0) {
    //         return 0;
    //     }
    //     VestVestingToken memory schedule = vestingDetails[_tokenId];
    //     uint256 precisionAdjustedClaimable;

    //     LPVestingSchedule lpVestingSchedule = vAmmInfo.[schedule.vestingScheduleIndex];
    //     SingleVestingSchedule singleVestingSchedule;
    //     if (_claimType == ClaimType.Single) {
    //         singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[_singleRewardsIndex];
    //     }

    //     uint256 lastClaimedAt = _claimType == ClaimType.Single
    //         ? schedule.lastClaimedAtRewardList[_singleRewardsIndex]
    //         : schedule.lastClaimedAt;

    //     uint256 vestingCliffPeriod = _claimType == ClaimType.Single
    //         ? singleVestingSchedule.vestingCliffPeriod
    //         : lpVestingSchedule.vestingCliffPeriod;

    //     uint256 vestingPeriod = _claimType == ClaimType.Single
    //         ? singleVestingSchedule.vestingPeriod
    //         : lpVestingSchedule.vestingPeriod;

    //     uint256 vestingCliff = depositData.lpDepositTime + vestingCliffPeriod;
    //     uint256 vestingExpiry = vestingCliff + vestingPeriod;
    //     uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;

    //     if (lastClaimedAt < maxTime && block.timestamp > vestingCliff) {
    //         uint256 minTime = lastClaimedAt == 0 ? vestingCliff : lastClaimedAt;

    //         uint256 totalShare = _claimType == ClaimType.Single
    //             ? (((singleVestingSchedule.totalSingleTokens * depositedPerVestSchedule[_vestingScheduleIndex]) /
    //                 maxInvTokensPerVestSchedule[_vestingScheduleIndex]) * schedule.amountDeposited) /
    //                 depositedPerVestSchedule[schedule.vestingScheduleIndex]
    //             : (lpTokenAmountPerSchedule[schedule.vestingScheduleIndex] * schedule.amountDeposited) /
    //                 depositedPerVestSchedule[schedule.vestingScheduleIndex];

    //         uint256 claimableAmount = vestingPeriod == 0 ? totalShare : (totalShare * (maxTime - minTime)) / vestingPeriod;
    //         address claimToken = _claimType == ClaimType.Single ? singleVestingSchedule.token : depositData.lpToken;

    //         // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
    //         // although it will generally never happen as solidity rounds down so there should always be a little bit left
    //         precisionAdjustedClaimable = tokensClaimable > IERC20(claimToken).balanceOf(address(this))
    //             ? IERC20(claimToken).balanceOf(address(this))
    //             : tokensClaimable;
    //     }
    //     return precisionAdjustedClaimable;
    // }

    /**
     * @dev allows a user to claim their all their vested tokens across a single NFT
     */
    // function claimAllTokensSingleNFT(uint256 _tokenId) public {
    //     claimLPTokens(_tokenId);
    //     VestVestingToken memory schedule = vestingDetails[_tokenId];
    //     LPVestingSchedule lpVestingSchedule = vAmmInfo.[schedule.vestingScheduleIndex];
    //     for (uint256 i; i < lpVestingSchedule.singleVestingSchedules.length; i++) {
    //         claimRewardToken(_tokenId, i);
    //     }
    // }

    // /**
    //  * @dev allows a user to claim their all their vested tokens across many NFTs
    //  */
    // function claimAllTokensManyNFTs(uint256[] _tokenIds) external {
    //     for (uint256 i; i < _tokenIds.length; i++) {
    //         claimAllTokensSingleNFT(_tokenIds[i]);
    //     }
    // }

    /**
     * @dev allows a user to claim their LP tokens or a partial amount
     * of their LP tokens once they have vested according to the schedule
     * created by the protocol
     */
    // function claimLPTokens(uint256 _tokenId) public {
    //     _claimTokens(_tokenId, ClaimType.LP, 0);
    // }

    // /**
    //  * @dev allows a user to claim their single sided reward tokens or a partial amount
    //  * of their single sided reward tokens once they have vested according to the schedule
    //  */
    // function claimRewardToken(uint256 _tokenId, uint256 _singleRewardsIndex) external {
    //     _claimTokens(_tokenId, ClaimType.Single, _singleRewardsIndex);
    // }

    // function _claimTokens(
    //     uint256 _tokenId,
    //     ClaimType _claimType,
    //     uint8 _singleRewardsIndex
    // ) internal {
    //     Validate.owner(ownerOf(_tokenId));
    //     if (_claimType == ClaimType.LP) {
    //         // TODO claim fees for the protocol. this fee amount should be the global total for all LP tokens
    //         // we want to know how many fees ALL the LP tokens have earned since the last time someone claimed
    //         // or since we called a public function which captures the fees
    //         collectAllFees();
    //     }
    //     uint256 claimableAmount = claimableTokens(_tokenId, _claimType, _singleRewardsIndex);
    //     Validate.hasClaimBalance(claimableAmount);
    //     VestVestingToken memory schedule = vestingDetails[_tokenId];
    //     address claimToken = _claimType == ClaimType.Single // How do you know which lpVestingSchedule to use?
    //         ? vAmmInfo.lpVestingSchedule.singleVestingSchedules[_singleRewardsIndex].token
    //         : depositData.lpToken;
    //     if (_claimType == ClaimType.Single) {
    //         vestingDetails[_tokenId].lastClaimedAtRewardList[_singleRewardsIndex] = block.timestamp;
    //         singleClaimedPerVestSchedule[schedule.vestingScheduleIndex][_singleRewardsIndex] += claimableAmount;
    //         totalSingleClaimed[claimToken] += claimableAmount;
    //     } else {
    //         vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
    //         totalLPClaimed += claimableAmount;
    //         lpClaimedPerVestSchedule[schedule.vestingScheduleIndex] += claimableAmount;
    //     }
    //     // TODO indicate to the VestAMMMultiRewards staking rewards contract that
    //     // a withdraw has occured and they now have less funds locked
    //     // the difficulty here is when you go to stake them you are using investment tokens
    //     // when you go to withdraw you are using LP units so they are not the same.
    //     if (_claimType == ClaimType.LP) {
    //         // TODO implement this logic to calculate the % of LP tokens you are withdrawing
    //         // since the rewards contract knows the % you invested they want to know the % you
    //         // are removing even though they are in different token formats. going in you have investment tokens
    //         // going out you have LP tokens
    //         VestAMMMultiRewards.withdraw(claimableAmount, depositData.lpTokenAmount);
    //     }
    //     IERC20(claimToken).safeTransfer(msg.sender, claimableAmount);
    //     emit ClaimedToken(
    //         claimToken,
    //         msg.sender,
    //         claimableAmount,
    //         _claimType,
    //         schedule.vestingScheduleIndex,
    //         _singleRewardsIndex
    //     );
    // }

    function sendFeesToAelin(address _token, uint256 _amount) public {
        // NOTE you don't just transfer fees to the AelinFeeModule because you need to track
        // which period they came in for AELIN stakers to be able to claim correctly from the AelinFeeModule

        // TODO
        // AelinFeeModule(aelinFeeModule).sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    function _validateSchedules(LPVestingSchedule[] memory _vestingSchedules) internal pure {
        Validate.maxVestingPeriods(MAX_LP_VESTING_SCHEDULES >= _vestingSchedules.length);
        for (uint256 i; i < _vestingSchedules.length; ++i) {
            Validate.vestingCliff(1825 days >= _vestingSchedules[i].vestingCliffPeriod);
            Validate.vestingPeriod(1825 days >= _vestingSchedules[i].vestingPeriod);
            Validate.investorShare(
                100 * 10**18 >= _vestingSchedules[i].investorLPShare && 0 <= _vestingSchedules[i].investorLPShare
            );
            Validate.hasTotalBaseTokens(_vestingSchedules[i].totalBaseTokens > 0);
            Validate.lpNotZero(_vestingSchedules[i].totalLPTokens > 0);
            Validate.nothingClaimed(_vestingSchedules[i].claimed == 0);
            Validate.maxSingleReward(MAX_SINGLE_REWARDS >= _vestingSchedules[i].singleVestingSchedules.length);
            _validateSingleVestingSched(_vestingSchedules[i].singleVestingSchedules);
        }
    }

    function _validateSingleVestingSched(SingleVestingSchedule[] memory _singleVestingSchedules) internal pure {
        for (uint256 i; i < _singleVestingSchedules.length; ++i) {
            Validate.singleVestingCliff(1825 days >= _singleVestingSchedules[i].vestingCliffPeriod);
            Validate.singleVestingPeriod(1825 days >= _singleVestingSchedules[i].vestingPeriod);
            Validate.hasTotalSingleTokens(_singleVestingSchedules[i].totalSingleTokens > 0);
            Validate.singleNothingClaimed(_singleVestingSchedules[i].claimed == 0);
            Validate.singleHolderNotNull(_singleVestingSchedules[i].singleHolder != address(0));
            Validate.singleDepositNotFinalized(!_singleVestingSchedules[i].finalizedDeposit);
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
    // function mintVestingToken(
    //     address _to,
    //     uint256 _amount,
    //     uint8 _vestingScheduleIndex
    // ) internal {
    //     uint256[] memory singleRewardTimestamps = new uint256[](
    //         vAmmInfo.lpVestingSchedules[_vestingScheduleIndex].singleVestingSchedules.length
    //     );
    //     // TODO
    //     // _mintVestingToken(_to, _amount, 0, singleRewardTimestamps, _vestingScheduleIndex);
    // }

    // // Does not like returning the array name
    function singleRewardsToDeposit(address _holder) external view returns (DepositToken[] memory) {
        DepositToken[] memory rewardsToDeposit = new DepositToken[](numSingleRewards);
        for (uint8 i = 0; i < vAmmInfo.lpVestingSchedules.length; i++) {
            for (uint8 j = 0; j < vAmmInfo.lpVestingSchedules[i].singleVestingSchedules.length; j++) {
                address singleHolder = vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].singleHolder;
                if (_holder == vAmmInfo.mainHolder || _holder == singleHolder) {
                    uint256 amountDeposited = holderDeposits[vAmmInfo.mainHolder][i][j] + holderDeposits[singleHolder][i][j];
                    DepositToken memory rewardToDeposit = DepositToken(
                        i,
                        j,
                        vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].rewardToken,
                        vAmmInfo.lpVestingSchedules[i].singleVestingSchedules[j].totalSingleTokens - amountDeposited
                    );
                    rewardsToDeposit[i * vAmmInfo.lpVestingSchedules[i].singleVestingSchedules.length + j] = rewardToDeposit;
                }
            }
        }
        return rewardsToDeposit;
    }

    modifier initOnce() {
        Validate.notInitialized(!calledInitialize);
        calledInitialize = true;
        _;
    }

    modifier onlyHolder() {
        Validate.callerIsHolder(msg.sender == vAmmInfo.mainHolder);
        _;
    }

    modifier depositIncomplete() {
        Validate.depositIncomplete(!depositComplete);
        _;
    }

    modifier dealOpen() {
        Validate.dealOpen(!isCancelled);
        _;
    }

    modifier depositWindowEnded() {
        //NOTE: double check logic
        Validate.depositWindowEnded(depositData.lpDepositTime == 0 && block.timestamp > lpFundingExpiry);
        _;
    }

    modifier lpFundingWindow() {
        Validate.notCancelled(!isCancelled);
        // TODO double check < vs <= matches everywhere
        Validate.inFundingWindow(depositComplete && block.timestamp > depositExpiry && block.timestamp <= lpFundingExpiry);
        _;
    }

    // TODO add require. ty
    modifier lpComplete() {
        // require lpDepositTime > 0
        Validate.fundingComplete(depositData.lpDepositTime > 0);
        _;
    }

    modifier acceptDealOpen() {
        Validate.notCancelled(isCancelled == false);
        // TODO double check < vs <= matches everywhere
        Validate.inDepositWindow(depositComplete && block.timestamp <= depositExpiry);
        _;
    }

    modifier vestingScheduleOpen(uint8 _vestingScheduleIndex, uint256 _investmentTokenAmount) {
        bool otherBucketsFull = true;
        // NOTE the logic we are using here is all buckets need to be full before you can over allocate
        // on any bucket. if any bucket is open you must fill that bucket before you can overflow any other bucket that
        // is already full
        for (uint8 i; i < numVestingSchedules; i++) {
            if (i == _vestingScheduleIndex) {
                continue;
            }
            if (!isVestingScheduleFull[i]) {
                otherBucketsFull = false;
                break;
            }
        }

        Validate.purchaseAmount(
            depositedPerVestSchedule[_vestingScheduleIndex] + _investmentTokenAmount <=
                maxInvTokensPerVestSchedule[_vestingScheduleIndex] ||
                (otherBucketsFull && vAmmInfo.deallocation == Deallocation.Proportional)
        );
        _;
    }

    modifier lock() {
        Validate.contractUnlocked(locked == false);
        locked = true;
        _;
        locked = false;
    }
}