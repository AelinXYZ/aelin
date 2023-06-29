// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "forge-std/console.sol";
// NEED pausing and management features
import "./VestVestingToken.sol";

// import "./VestAMMMultiRewards.sol";
import {VestVestingToken} from "./VestVestingToken.sol";
import {VestAMMMultiRewards} from "./VestAMMMultiRewards.sol";

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

import "./libraries/validation/VestAMMValidation.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/**
 * @title VestAMM logic contract
 * @author Aelin CCs
 * @notice This contract holds the VestAMM logic. It will be deployed once and all
 * VestAMM instances will be deployed at Minimal Proxy contracts pointing to this logic.
 * @dev there are 5 phases to VestAMM:
 *   1. holders deposit base asset (e.g. SNX) and single sided rewards (e.g. OP, BAL)
 *   2. community provides liquidity (e.g. sUSD)
 *   3. protocol adds liquidity to selected AMM (e.g. sUSD/SNX 50/50 pair on Balancer)
 *   4. vesting phase (optional for LP tokens and single sided rewards)
 *   5. deal complete (LP tokens and single sided rewards fully vested)
 */
contract VestAMM is VestVestingToken, IVestAMM {
    using SafeERC20 for IERC20;

    uint256 constant VEST_ASSET_FEE = 1 * 10 ** 18;
    uint256 constant VEST_SWAP_FEE = 20 * 10 ** 18;
    uint256 constant VEST_BASE_FEE = 100 * 10 ** 18;
    uint256 public depositExpiry;
    uint256 public lpFundingExpiry;
    uint256 public totalLPClaimed;
    uint256 public totalBaseTokens;
    uint256 public maxInvTokens;
    uint256 public amountBaseDeposited;
    uint256 public lpClaimed;
    mapping(address => uint256) totalSingleClaimed;
    mapping(uint8 => mapping(uint8 => uint256)) public holderDeposits;
    uint8 private singleRewardsComplete;
    uint8 maxSingleRewards = 6;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;
    address public aelinFeeModule;

    uint256 public totalInvTokensDeposited;
    uint256 investmentTokenPerBase;

    address public vestAmmMultiRewards;
    VAmmInfo public vAmmInfo;
    DealAccess public dealAccess;

    bool private calledInitialize;
    bool private baseComplete;
    bool public isCancelled;
    bool public depositComplete;
    DepositData public depositData;

    IVestAMMLibrary internal vestAMMLibrary;

    bool public locked = false;

    /**
     * @dev initializes the contract configuration, called from the factory contract
     * when creating a new Vest AMM (vAMM) instance
     */
    function initialize(
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess,
        address _aelinFeeModule,
        address _aelinMultiRewards
    ) external initOnce {
        _validateLPSchedule(_vAmmInfo.lpVestingSchedule);
        _validateSingleSchedules(_vAmmInfo.singleVestingSchedules);
        _setNameAndSymbol(
            string(abi.encodePacked("vAMM-", _vAmmInfo.name)),
            string(abi.encodePacked("v-", _vAmmInfo.symbol))
        );
        vAmmInfo = _vAmmInfo;
        dealAccess = _dealAccess;
        vestAMMLibrary = IVestAMMLibrary(_vAmmInfo.ammData.ammLibrary);
        aelinFeeModule = _aelinFeeModule;

        vestAmmMultiRewards = Clones.clone(_aelinMultiRewards);
        VestAMMMultiRewards(vestAmmMultiRewards).initialize(vAmmInfo.mainHolder);
        emit MultiRewardsCreated(vestAmmMultiRewards);

        // TODO when a new pool is for a token that has liquidity elsewhere
        // we prob want to have another price check somehow
        // maybe both now and when the liquidity is added. we can ask for the
        // address and AMM where liquidity is already or check it ourselves in the contract
        if (!_vAmmInfo.hasLaunchPhase) {
            Validate.poolExists(vestAMMLibrary.checkPoolExists(vAmmInfo));
            investmentTokenPerBase = vestAMMLibrary.getPriceRatio(vAmmInfo);
        }
        uint256 invPerBase = _vAmmInfo.hasLaunchPhase ? _vAmmInfo.investmentPerBase : investmentTokenPerBase;

        totalBaseTokens = vAmmInfo.lpVestingSchedule.totalBaseTokens;

        maxInvTokens = (totalBaseTokens * invPerBase) / 10 ** IERC20(vAmmInfo.ammData.baseToken).decimals();

        // NOTE can just approve later before we provide liquidity. this is probably better
        IERC20(vAmmInfo.ammData.baseToken).approve(address(vestAMMLibrary), totalBaseTokens);
        IERC20(vAmmInfo.ammData.investmentToken).approve(address(vestAMMLibrary), maxInvTokens);

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

    /**
     * @dev this function is called at the end of a deposit method. Either for the base
     * token or single sided reward deposit. If all the tokens have been deposited
     * this function will begin the deposit window for community members to provide liquidity
     */
    function setDepositComplete() internal {
        if (baseComplete == true && singleRewardsComplete == vAmmInfo.singleVestingSchedules.length) {
            depositComplete = true;
            depositExpiry = block.timestamp + vAmmInfo.depositWindow;
            lpFundingExpiry = depositExpiry + vAmmInfo.lpFundingWindow;
            emit DepositComplete(depositExpiry, lpFundingExpiry);
        }
    }

    /**
     * @dev this function allows the single sided rewards holders to deposit their token which must
     * happen before any community members can deposit liquidity
     * @param _depositTokens an array of token, amount and index of single sided reward. The depositor
     * must be the appointed single sided rewards holder and must do it before the deal is fully funded and not cancelled
     */
    function depositSingle(DepositToken[] calldata _depositTokens) external depositIncomplete dealOpen {
        for (uint i = 0; i < _depositTokens.length; i++) {
            SingleVestingSchedule singleVestingSchedule = vAmmInfo.singleVestingSchedules[
                _depositTokens[i].singleRewardIndex
            ];
            Validate.singleHolder(singleVestingSchedule.singleHolder == msg.sender);
            Validate.singleToken(_depositTokens[i].token == singleVestingSchedule.rewardToken);
            Validate.singleDepositNotFinalized(!singleVestingSchedule.finalizedDeposit);

            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).safeTransferFrom(msg.sender, address(this), _depositTokens[i].amount);
            uint256 balanceAfterTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;

            holderDeposits[msg.sender][_depositTokens[i].singleRewardIndex] += amountPostTransfer;

            emit SingleRewardDeposited(
                msg.sender,
                _depositTokens[i].singleRewardIndex,
                _depositTokens[i].token,
                amountPostTransfer
            );
            if (
                !singleVestingSchedule.finalizedDeposit &&
                holderDeposits[msg.sender][_depositTokens[i].singleRewardIndex] >= singleVestingSchedule.totalSingleTokens
            ) {
                singleRewardsComplete += 1;
                singleVestingSchedule.finalizedDeposit = true;
                emit SingleDepositComplete(_depositTokens[i].token, _depositTokens[i].singleRewardIndex);
            }
        }
        setDepositComplete();
    }

    /**
     * @dev this function cancels VestAMM and can be called by the base asset holder before the deposit
     * phase is complete. It will auto refund any deposits that have been sent in so far
     */
    function cancelAndRefundVestAMM() external onlyHolder depositIncomplete {
        if (amountBaseDeposited > 0) {
            IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, amountBaseDeposited);
        }
        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules; i++) {
            removeSingle(RemoveSingle(i, vAmmInfo.singleVestingSchedules[i].token));
        }
        isCancelled = true;
    }

    function addSingle(SingleVestingSchedule[] calldata _newSingleRewards) external onlyHolder depositIncomplete dealOpen {
        Validate.maxSingleRewards(maxSingleRewards <= vAmmInfo.singleVestingSchedules.length + _newSingleRewards.length);
        _validateSingleSchedules(_newSingleRewards);
        for (uint8 i = 0; i < _newSingleRewards; i++) {
            vAmmInfo.singleVestingSchedules[vAmmInfo.singleVestingSchedules.length] = _newSingleRewards[i];
        }
    }

    function removeSingle(RemoveSingle[] calldata _removeSingleList) external depositIncomplete {
        for (uint8 i = 0; i < _removeSingleList.length; i++) {
            SingleVestingSchedule singleVestingSchedule = vAmmInfo.singleVestingSchedules[
                _removeSingleList[i].singleRewardIndex
            ];
            Validate.singleHolder(vAmmInfo.mainHolder == msg.sender || singleVestingSchedule.singleHolder == msg.sender);
            uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][
                _removeSingleList[i].singleRewardIndex
            ];
            if (singleHolderAmount > 0) {
                IERC20(singleRewards[_removeSingleList[i]].token).safeTransferFrom(
                    address(this),
                    singleRewards[_removeSingleList[i]].singleHolder,
                    singleHolderAmount
                );
            }
            emit SingleRemoved(
                _removeSingleList[i].singleRewardIndex,
                singleRewards[_removeSingleList[i]].token,
                singleRewards[_removeSingleList[i]].rewardTokenTotal,
                singleHolderAmount
            );
        }

        if (singleVestingSchedule.finalizedDeposit) {
            singleRewardsComplete -= 1;
        }

        if (_removeSingleList[i].singleRewardIndex != vAmmInfo.singleVestingSchedules.length - 1) {
            vAmmInfo.singleVestingSchedules[_removeSingleList[i].singleRewardIndex] = vAmmInfo.singleVestingSchedules[
                vAmmInfo.singleVestingSchedules.length - 1
            ];
            holderDeposits[singleVestingSchedule.singleHolder][_removeSingleList[i].singleRewardIndex] = holderDeposits[
                singleVestingSchedule.singleHolder
            ][vAmmInfo.singleVestingSchedules.length - 1];
        }
        delete vAmmInfo.singleVestingSchedules[vAmmInfo.singleVestingSchedules.length - 1];
        delete holderDeposits[singleVestingSchedule.singleHolder][vAmmInfo.singleVestingSchedules.length - 1];
    }

    function removeSingles(RemoveSingle[] calldata _removeSingleList) external {
        for (uint8 i = 0; i < _removeSingleList.length; i++) {
            removeSingle(_removeSingleList[i]);
        }
    }

    function depositBase() external onlyHolder depositIncomplete dealOpen {
        Validate.baseDepositNotCompleted(!baseComplete);
        address baseToken = vAmmInfo.ammData.baseToken;

        uint256 balanceBeforeTransfer = IERC20(baseToken).balanceOf(address(this));
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), totalBaseTokens);
        uint256 balanceAfterTransfer = IERC20(baseToken).balanceOf(address(this));
        uint256 amountPostTransfer = balanceAfterTransfer - balanceBeforeTransfer;
        amountBaseDeposited += amountPostTransfer;
        emit BaseDeposited(baseToken, msg.sender, amountPostTransfer, amountBaseDeposited);
        if (amountBaseDeposited >= totalBaseTokens) {
            baseComplete = true;
        }

        setDepositComplete();
    }

    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _investmentTokenAmount
    ) external lock acceptDealOpen {
        Validate.investmentTokenBalance(
            IERC20(vAmmInfo.ammData.investmentToken).balanceOf(msg.sender) >= _investmentTokenAmount
        );
        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _investmentTokenAmount);
        } else if (allowList.hasAllowList) {
            Validate.investorAllocation(
                allowList.amounsingleVestingSchedulesPerAddress[msg.sender] >= _investmentTokenAmount
            );
            allowList.amountPerAddress[msg.sender] -= _investmentTokenAmount;
        } else if (dealAccess.merkleRoot != 0) {
            MerkleTree.purchaseMerkleAmount(_merkleData, trackClaimed, _investmentTokenAmount, dealAccess.merkleRoot);
        }
        uint256 balanceBeforeTransfer = IERC20(vAmmInfo.ammData.investmentToken).balanceOf(address(this));
        IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(msg.sender, address(this), _investmentTokenAmount);
        uint256 balanceAfterTransfer = IERC20(vAmmInfo.ammData.investmentToken).balanceOf(address(this));
        uint256 depositTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;
        totalInvTokensDeposited += depositTokenAmount;
        // NOTE no deallocation allowed for v1
        require(totalInvTokensDeposited >= maxInvTokens, "investment cap exceeded");

        VestAMMMultiRewards(vestAmmMultiRewards).stake(depositTokenAmount, msg.sender);
        _mintVestingToken(msg.sender, depositTokenAmount, 0);

        emit AcceptVestDeal(msg.sender, depositTokenAmount);
    }

    function createInitialLiquidity() external onlyHolder lpFundingWindow {
        Validate.liquidityLaunch(vAmmInfo.hasLaunchPhase);

        address poolAddress = vestAMMLibrary.deployPool(vAmmInfo.newPoolData);
        IVestAMMLibrary.AddLiquidity memory addLiquidity = createAddLiquidity(poolAddress);
        (, , numInvTokensFee, numBaseTokensFee) = vestAMMLibrary.addInitialLiquidity(addLiquidity);
        saveDepositData(poolAddress);

        aelinFees(numInvTokensFee, numBaseTokensFee);
    }

    function createLiquidity(uint256 _extraBaseTokens) external onlyHolder lpFundingWindow {
        address baseToken = vAmmInfo.ammData.baseToken;
        Validate.notLiquidityLaunch(vAmmInfo.hasLiquidityLaunch);
        uint256 currentRatio = vestAMMLibrary.getPriceRatio(vAmmInfo);
        (
            uint256 excessBaseTokensInLP,
            uint256 currentBaseTokensInLP,
            uint256 baseTokensDeposited
        ) = _getExcessBaseTokensData(currentRatio);

        if (currentRatio > investmentTokenPerBase) {
            uint256 holderRefundAmt = baseTokensDeposited - (excessBaseTokensInLP + currentBaseTokensInLP);
            IERC20(baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, holderRefundAmt);

            IVestAMM.SingleVestingSchedule memory extraSingleVestingSchedule = IVestAMM.SingleVestingSchedule(
                baseToken,
                vAmmInfo.mainHolder,
                excessBaseTokensInLP,
                0,
                false,
                true
            );

            vAmmInfo.singleVestingSchedules.push(extraSingleVestingSchedule);
            maxSingleRewards += 1;
        } else if (currentRatio < investmentTokenPerBase) {
            Validate.maxExcessBaseTokens(excessBaseTokensInLP >= _extraBaseTokens);
            uint256 balanceBeforeTransfer = IERC20(baseToken).balanceOf(address(this));
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), _extraBaseTokens);
            uint256 balanceAfterTransfer = IERC20(baseToken).balanceOf(address(this));
            uint256 excessTransferred = balanceAfterTransfer - balanceBeforeTransfer;
        }

        AddLiquidity addLiquidity = createAddLiquidity();
        (numInvTokensFee, numBaseTokensFee) = vestAMMLibrary.addLiquidity(addLiquidity);

        saveDepositData(vAmmInfo.poolAddress);
        aelinFees(numInvTokensFee, numBaseTokensFee);
    }

    function _getExcessBaseTokensData(uint256 _currentRatio) internal view returns (uint256, uint256, uint256) {
        uint256 investmentTokenTarget = vAmmInfo.lpVestingSchedule.totalBaseTokens * vAmmInfo.investmentPerBase;
        uint256 investmentTokenRaised = IERC20(vAmmInfo.ammData.investmentToken).balanceOf(address(this));
        uint256 baseTokenDeposited = IERC20(vAmmInfo.ammData.baseToken).balanceOf(address(this));

        uint256 initialBaseTokensInLP = baseTokenDeposited * (investmentTokenRaised / investmentTokenTarget);
        uint256 currentBaseTokensInLP = investmentTokenRaised / (_currentRatio);

        uint256 excessBaseTokens = _currentRatio > investmentTokenPerBase
            ? initialBaseTokensInLP - currentBaseTokensInLP
            : currentBaseTokensInLP;

        return (excessBaseTokens, currentBaseTokensInLP, baseTokenDeposited);
    }

    function saveDepositData(address _poolAddress) internal {
        // We might have to add a method to the librariers IVestAMMLibrary.balanceOf
        depositData = DepositData(_poolAddress, IERC20(_poolAddress).balanceOf(address(this)), block.timestamp);
    }

    function createAddLiquidity(address _poolAddress) internal view returns (IVestAMMLibrary.AddLiquidity memory) {
        // TODO add in the other variables needed to deploy a pool and return these values
        uint256 investmentTokenAmount = totalInvTokensDeposited < maxInvTokens ? totalInvTokensDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalInvTokensDeposited < maxInvTokens
            ? (totalBaseTokens * totalInvTokensDeposited) / maxInvTokens
            : totalBaseTokens;

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
        uint256 investmentTokenAmount = totalInvTokensDeposited < maxInvTokens ? totalInvTokensDeposited : maxInvTokens;
        uint256 baseTokenAmount = totalInvTokensDeposited < maxInvTokens
            ? (totalBaseTokens * totalInvTokensDeposited) / maxInvTokens
            : totalBaseTokens;

        return DeployPool(investmentTokenAmount, baseTokenAmount);
    }

    function aelinFees(uint256 _invTokenFeeAmt, uint256 _baseTokenFeeAmt) internal {
        sendFeesToAelin(ammData.baseToken, _baseTokenFeeAmt);
        sendFeesToAelin(ammData.investmentAsset, _baseTokenFeeAmt);

        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            SingleVestingSchedule singleVestingSchedule = vAmmInfo.singleVestingSchedules[i];

            uint256 singleRewardsUsed = (singleVestingSchedule.totalSingleTokens * totalInvTokensDeposited) / maxInvTokens;

            uint256 feeAmount = (singleRewardsUsed * VEST_ASSET_FEE) / VEST_BASE_FEE;
            sendFeesToAelin(_singleRewards[i].token, feeAmount);
        }
    }

    function withdrawExcessFunding() public lpComplete {
        uint256 excessBaseAmount = vAmmInfo.lpVestingSchedule.totalBaseTokens -
            ((vAmmInfo.lpVestingSchedule.totalBaseTokens * totalInvTokensDeposited) / maxInvTokens);
        IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, excessBaseAmount);

        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = lpVestingSchedule.singleVestingSchedules[i];

            uint256 singleHolderAmount = holderDeposits[singleVestingSchedule.singleHolder][i];
            uint256 excessAmount = singleVestingSchedule.totalSingleTokens -
                ((singleVestingSchedule.totalSingleTokens * totalInvTokensDeposited) / maxInvTokens);
            if (excessSingleAmount > 0) {
                IERC20(singleVestingSchedule.rewardToken).safeTransferFrom(
                    address(this),
                    singleVestingSchedule.singleHolder,
                    excessSingleAmount
                );
            }
        }
    }

    // for when the lp is not funded in time
    function depositorWithdraw(uint256[] _tokenIds) external neverDeposited {
        for (uint256 i; i < _tokenIds.length; i++) {
            Validate.owner(ownerOf(_tokenIds[i]));
            VestVestingToken memory schedule = vestingDetails[_tokenIds[i]];
            IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(address(this), msg.sender, schedule.amountDeposited);
            emit Withdraw(msg.sender, schedule.amountDeposited);
        }
    }

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

    function calcVestTimes(
        uint256 _tokenId
    ) internal view returns (uint256 vestingCliff, uint256 vestingExpiry, uint256 maxTime) {
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        LPVestingSchedule lpVestingSchedule = vAmmInfo.lpVestingSchedule;

        vestingCliff = depositData.lpDepositTime + vAmmInfo.lpVestingSchedule.vestingCliffPeriod;
        vestingExpiry = vestingCliff + vAmmInfo.lpVestingSchedule.vestingPeriod;
        maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
    }

    function claimableSingleTokens(uint256 _tokenId, uint256 _singleRewardIndex) public view returns (uint256, address) {
        if (depositData.lpDepositTime == 0 || _singleRewardIndex >= vAmmInfo.singleVestingSchedules.length) {
            return (0, address(0));
        }
        SingleVestingSchedule singleVestingSchedule = vAmmInfo.singleVestingSchedules[_singleRewardIndex];
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        (uint256 vestingCliff, uint256 vestingExpiry, uint256 maxTime) = calcVestTimes(_tokenId);

        if (
            (schedule.lastClaimedAt < maxTime && block.timestamp > vestingCliff) ||
            (singleVestingSchedule.isLiquid && schedule.lastClaimedAt > 0)
        ) {
            uint256 minTime = schedule.lastClaimedAt == 0 ? vestingCliff : schedule.lastClaimedAt;

            uint256 totalShare = (singleVestingSchedule.totalSingleTokens * schedule.amountDeposited) /
                totalInvTokensDeposited;

            uint256 claimableAmount = (vestingPeriod == 0 || singleVestingSchedule.isLiquid)
                ? totalShare
                : (totalShare * (maxTime - minTime)) / vestingPeriod;

            uint256 precisionAdjustedClaimable = tokensClaimable >
                IERC20(singleVestingSchedule.token).balanceOf(address(this))
                ? IERC20(singleVestingSchedule.token).balanceOf(address(this))
                : tokensClaimable;

            return (precisionAdjustedClaimable, singleVestingSchedule.token);
        }
        return (0, singleVestingSchedule.token);
    }

    function claimableLPTokens(uint256 _tokenId) public view returns (uint256, address) {
        if (depositData.lpDepositTime == 0) {
            return (0, depositData.lpToken);
        }
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        (uint256 vestingCliff, uint256 vestingExpiry, uint256 maxTime) = calcVestTimes(_tokenId);

        if (schedule.lastClaimedAt < maxTime && block.timestamp > vestingCliff) {
            uint256 minTime = schedule.lastClaimedAt == 0 ? vestingCliff : schedule.lastClaimedAt;

            uint256 totalShare = (totalBaseTokens * schedule.amountDeposited) / totalInvTokensDeposited;

            uint256 claimableAmount = vestingPeriod == 0 ? totalShare : (totalShare * (maxTime - minTime)) / vestingPeriod;

            uint256 precisionAdjustedClaimable = tokensClaimable > IERC20(depositData.lpToken).balanceOf(address(this))
                ? IERC20(depositData.lpToken).balanceOf(address(this))
                : tokensClaimable;

            return (precisionAdjustedClaimable, depositData.lpToken);
        }
        return (0, depositData.lpToken);
    }

    // NOTE we need to update the multi rewards contract when a NFT transfer happens
    function claimMultiRewards(uint256 _tokenId) {
        Validate.owner(ownerOf(_tokenId));
        getReward(msg.sender);
    }

    /**
     * @dev allows a user to claim their all their vested tokens across a single NFT
     */
    function claimAllTokens(uint256 _tokenId) public {
        Validate.owner(ownerOf(_tokenId));
        collectAllFees();
        vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        (uint256 lpAmount, address lpAddress) = claimableLPTokens(_tokenId);
        _claimLPTokens(_tokenId, lpAmount, lpAddress);
        for (uint256 i; i < lpVestingSchedule.singleVestingSchedules.length; i++) {
            (uint256 singleAmount, address singleAddress) = claimableSingleTokens(_tokenId);
            _claimSingleTokens(_tokenId, singleAmount, singleAddress, i);
        }
    }

    /**
     * @dev allows a user to claim their all their vested tokens across many NFTs
     */
    function claimAllTokensManyNFTs(uint256[] _tokenIds) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            claimAllTokens(_tokenIds[i]);
        }
    }

    function _claimLPTokens(uint256 _tokenId, uint256 _claimableAmount, address _token) internal {
        Validate.hasClaimBalance(_claimableAmount);
        totalLPClaimed += _claimableAmount;
        uint256 withdrawAmount = (totalInvTokensDeposited * _claimableAmount) / depositData.lpTokenAmount;
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(withdrawAmount, msg.sender);
        IERC20(_token).safeTransfer(msg.sender, _claimableAmount);
        emit ClaimedToken(_token, msg.sender, _claimableAmount, ClaimType.LP, -1);
    }

    function _claimSingleTokens(
        uint256 _tokenId,
        uint256 _claimableAmount,
        address _token,
        uint256 _singleRewardsIndex
    ) internal {
        Validate.hasClaimBalance(_claimableAmount);
        totalSingleClaimed[_token] += _claimableAmount;
        IERC20(_token).safeTransfer(msg.sender, _claimableAmount);
        emit ClaimedToken(_token, msg.sender, _claimableAmount, ClaimType.Single, _singleRewardsIndex);
    }

    function sendFeesToAelin(address _token, uint256 _amount) public {
        IERC20(_token).approve(aelinFeeModule, _amount);
        AelinFeeModule(aelinFeeModule).sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    function _validateLPSchedule(LPVestingSchedule _vestingSchedule) internal {
        Validate.vestingCliff(1825 days >= _vestingSchedule.vestingCliffPeriod);
        Validate.vestingPeriod(1825 days >= _vestingSchedule.vestingPeriod);
        Validate.investorShare(100 * 10 ** 18 >= _vestingSchedule.investorLPShare && 0 <= _vestingSchedule.investorLPShare);
        Validate.hasTotalBaseTokens(_vestingSchedule.totalBaseTokens > 0);
        Validate.lpNotZero(_vestingSchedule.totalLPTokens > 0);
        Validate.nothingClaimed(_vestingSchedule.claimed == 0);
        Validate.maxSingleReward(maxSingleRewards >= _vestingSchedule.singleVestingSchedules.length);
    }

    function _validateSingleSchedules(SingleVestingSchedule[] _singleVestingSchedules) internal {
        for (uint256 i; i < _singleVestingSchedules.length; ++i) {
            Validate.hasTotalSingleTokens(_singleVestingSchedules[i].totalSingleTokens > 0);
            Validate.singleNothingClaimed(_singleVestingSchedules[i].claimed == 0);
            Validate.singleHolderNotNull(_singleVestingSchedules[i].singleHolder != address(0));
            Validate.depositNotFinalized(_singleVestingSchedules[i].finalizedDeposit);
        }
    }

    function transferVestingShare(address _to, uint256 _tokenId, uint256 _shareAmount) {
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(_shareAmount, msg.sender);
        VestAMMMultiRewards(vestAmmMultiRewards).stake(_shareAmount, _to);
        _transferVestingShare(_to, _tokenId, _shareAmount);
    }

    function transfer(_to, _tokenId) {
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(schedule.amountDeposited, msg.sender);
        VestAMMMultiRewards(vestAmmMultiRewards).stake(schedule.amountDeposited, _to);
        _transfer(_to, _tokenId, []);
    }

    function singleRewardsToDeposit(address _holder) external view returns (DepositToken[] memory) {
        DepositToken[] memory rewardsToDeposit = new DepositToken[]();
        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            address singleHolder = vAmmInfo.singleVestingSchedules[i].singleHolder;
            if (_holder == singleHolder && !vAmmInfo.singleVestingSchedules[i].finalizedDeposit) {
                uint256 amountDeposited = holderDeposits[singleHolder][i];
                DepositToken memory rewardToDeposit = DepositToken(
                    i,
                    vAmmInfo.singleVestingSchedules[i].rewardToken,
                    vAmmInfo.singleVestingSchedules[i].totalSingleTokens - amountDeposited
                );
                rewardsToDeposit.push(rewardToDeposit);
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

    modifier neverDeposited() {
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
        Validate.notCancelled(!isCancelled);
        // TODO double check < vs <= matches everywhere
        Validate.inDepositWindow(depositComplete && block.timestamp <= depositExpiry);
        _;
    }

    modifier lock() {
        Validate.contractUnlocked(!locked);
        locked = true;
        _;
        locked = false;
    }
}
