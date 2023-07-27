// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {VestVestingToken} from "./VestVestingToken.sol";
import {VestAMMMultiRewards} from "./VestAMMMultiRewards.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IVestAMM} from "./interfaces/IVestAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Decimals} from "./interfaces/IERC20Decimals.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {AelinNftGating} from "../libraries/AelinNftGating.sol";
import {AelinAllowList} from "../libraries/AelinAllowList.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";
import {Validate} from "./libraries/VestAMMValidation.sol";

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
 *
 * NOTE This contract still requires extensive testing and refining before deploying to
 * a live network.
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

    // depositor => depositIndex => amount
    mapping(address => mapping(uint8 => uint256)) public holderDeposits;

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

    bool public locked = false;

    /// @dev These need integrating into the initialise function
    VestVestingToken[] public vestingDetails;
    uint256 public tokensClaimable;
    uint256 public vestingPeriod;

    //////////
    // Init //
    //////////

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

        aelinFeeModule = _aelinFeeModule;
        vestAmmMultiRewards = Clones.clone(_aelinMultiRewards);
        VestAMMMultiRewards(vestAmmMultiRewards).initialize(vAmmInfo.mainHolder);
        emit MultiRewardsCreated(vestAmmMultiRewards);

        uint256 invPerBase;

        if (_vAmmInfo.hasLaunchPhase) {
            invPerBase = _vAmmInfo.investmentPerBase;
        } else {
            // TODO when a new pool is for a token that has liquidity elsewhere
            // we prob want to have another price check somehow
            // maybe both now and when the liquidity is added. we can ask for the
            // address and AMM where liquidity is already or check it ourselves in the contract
            Validate.poolExists(checkPoolExists());

            init();

            invPerBase = getPriceRatio();
        }

        totalBaseTokens = vAmmInfo.lpVestingSchedule.totalBaseTokens;

        maxInvTokens = (totalBaseTokens * invPerBase) / 10 ** IERC20Decimals(vAmmInfo.ammData.baseToken).decimals();

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
     * @dev a helper function to validate LP vesting schedule data
     * @param _vestingSchedule data for the LP vesting schedule
     */
    function _validateLPSchedule(LPVestingSchedule calldata _vestingSchedule) internal {
        Validate.vestingCliff(1825 days >= _vestingSchedule.vestingCliffPeriod);
        Validate.vestingPeriod(1825 days >= _vestingSchedule.vestingPeriod);
        Validate.investorShare(100 * 10 ** 18 >= _vestingSchedule.investorLPShare && 0 <= _vestingSchedule.investorLPShare);
        Validate.hasTotalBaseTokens(_vestingSchedule.totalBaseTokens > 0);
        Validate.lpNotZero(_vestingSchedule.totalLPTokens > 0);
        Validate.maxSingleReward(maxSingleRewards >= vAmmInfo.singleVestingSchedules.length);
    }

    /**
     * @dev a helper function to validate single reward vesting schedule data
     * @param _singleVestingSchedules data for the array of single vesting schedules
     */
    function _validateSingleSchedules(SingleVestingSchedule[] calldata _singleVestingSchedules) internal pure {
        for (uint256 i; i < _singleVestingSchedules.length; ++i) {
            Validate.hasTotalSingleTokens(_singleVestingSchedules[i].totalSingleTokens > 0);
            Validate.singleHolderNotNull(_singleVestingSchedules[i].singleHolder != address(0));
            Validate.depositNotFinalized(!_singleVestingSchedules[i].finalizedDeposit);
        }
    }

    //////////////////
    // Deposit Base //
    //////////////////

    /**
     * @dev this function is for the base asset holder to deposit their token. once the base asset
     * and all single sided rewards have been deposited the community can start adding liquidity
     */
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

    ////////////////////
    // Deposit Single //
    ////////////////////

    /**
     * @dev this function allows the single sided rewards holders to deposit their token which must
     * happen before any community members can deposit liquidity
     * @param _depositTokens an array of token, amount and index of single sided reward. The depositor
     * must be the appointed single sided rewards holder and must do it before the deal is fully funded and not cancelled
     */
    function depositSingle(DepositToken[] calldata _depositTokens) external depositIncomplete dealOpen {
        for (uint i = 0; i < _depositTokens.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = vAmmInfo.singleVestingSchedules[
                _depositTokens[i].singleRewardIndex
            ];
            Validate.singleHolder(singleVestingSchedule.singleHolder == msg.sender);
            Validate.singleToken(_depositTokens[i].token == singleVestingSchedule.rewardToken);
            Validate.singleDepositNotFinalized(!singleVestingSchedule.finalizedDeposit);

            uint256 balanceBeforeTransfer = IERC20(_depositTokens[i].token).balanceOf(address(this));
            IERC20(_depositTokens[i].token).transferFrom(msg.sender, address(this), _depositTokens[i].amount);
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
     * @dev this function allows for the base asset holder to add new single sided rewards so long
     * as the holder deposit window is still open and the community deposit window has not started yet
     * @param _newSingleRewards an array of new single vesting schedules up to 6 in total for the entire VestAMM instance
     */
    function addSingle(SingleVestingSchedule[] calldata _newSingleRewards) external onlyHolder depositIncomplete dealOpen {
        Validate.maxSingleReward(maxSingleRewards <= vAmmInfo.singleVestingSchedules.length + _newSingleRewards.length);
        _validateSingleSchedules(_newSingleRewards);
        for (uint8 i = 0; i < _newSingleRewards.length; i++) {
            vAmmInfo.singleVestingSchedules[vAmmInfo.singleVestingSchedules.length] = _newSingleRewards[i];
        }
    }

    //////////////////////////
    // Cancel VestAMM SetUp //
    //////////////////////////

    /**
     * @dev this function cancels VestAMM and can be called by the base asset holder before the deposit
     * phase is complete. It will auto refund any deposits that have been sent in so far
     */
    function cancelAndRefundVestAMM() external onlyHolder depositIncomplete {
        if (amountBaseDeposited > 0) {
            IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, amountBaseDeposited);
        }
        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            /// @dev double check this logic
            IERC20(vAmmInfo.singleVestingSchedules[i].rewardToken).safeTransferFrom(
                address(this),
                vAmmInfo.singleVestingSchedules[i].singleHolder,
                vAmmInfo.singleVestingSchedules[i].totalSingleTokens
            );
        }
        isCancelled = true;
    }

    /**
     * @dev this function allows the single sided rewards holders or the base asset holder to remove any single sided reward
     * all the deposited tokens will be refunded when a single sided reward is cancelled
     * @param _removeSingleList an array of single reward indexes to remove and refund
     */
    function removeSingle(SingleVestingSchedule[] calldata _removeSingleList) external depositIncomplete {
        /// @dev it might be better to pass an array of indices here???
        for (uint8 i = 0; i < _removeSingleList.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = vAmmInfo.singleVestingSchedules[i];
            Validate.singleHolder(vAmmInfo.mainHolder == msg.sender || singleVestingSchedule.singleHolder == msg.sender);

            /// NOTE Triple-check this logic, not sure it works as initially intended
            uint8 singleHolderAmount = uint8(holderDeposits[msg.sender][uint8(_removeSingleList[i].totalSingleTokens)]);

            if (singleVestingSchedule.finalizedDeposit) {
                singleRewardsComplete -= 1;
            }

            if (_removeSingleList.length != vAmmInfo.singleVestingSchedules.length - 1) {
                vAmmInfo.singleVestingSchedules[singleHolderAmount] = vAmmInfo.singleVestingSchedules[
                    vAmmInfo.singleVestingSchedules.length - 1
                ];
                holderDeposits[singleVestingSchedule.singleHolder][singleHolderAmount] = holderDeposits[
                    singleVestingSchedule.singleHolder
                ][uint8(vAmmInfo.singleVestingSchedules.length - 1)];
            }

            delete vAmmInfo.singleVestingSchedules[vAmmInfo.singleVestingSchedules.length - 1];
            delete holderDeposits[singleVestingSchedule.singleHolder][uint8(vAmmInfo.singleVestingSchedules.length - 1)];
        }
    }

    /////////////////
    // Accept Deal //
    /////////////////

    /**
     * @dev this function is for the community to add in liquidity in the paired asset decided by the
     * base asset holder. e.g. if the base asset holder is Synthetix Protocol and the base asset is SNX
     * the paired asset might be wETH or sUSD, which the community will provide in this method
     * @param _nftPurchaseList is the NFT gated deal info from the community member denoting which NFTs they will use
     * @param _merkleData is the merkle tree data for a user who is allowed to invest in a large allow list deal
     * @param _investmentTokenAmount is the amount of the paired asset a community member wants to deposit
     * @param _vestingScheduleIndex is the vesting schedule index for the deal
     */
    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _investmentTokenAmount,
        uint8 _vestingScheduleIndex
    ) external lock acceptDealOpen {
        // TODO check that the vesting schedule index is valid
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
        totalInvTokensDeposited += depositTokenAmount;
        // NOTE no deallocation allowed for v1
        require(totalInvTokensDeposited <= maxInvTokens, "investment cap exceeded");
        // TODO if the cap is hit we can move it to the next phase without waiting
        // NOTE change the deposit expiry and lp funding window to now when cap is hit

        VestAMMMultiRewards(vestAmmMultiRewards).stake(depositTokenAmount, msg.sender);
        _mintVestingToken(msg.sender, depositTokenAmount, 0);

        emit AcceptVestDeal(msg.sender, depositTokenAmount, _vestingScheduleIndex);
    }

    //////////////////////////////
    // Create Initial Liquidity //
    //////////////////////////////

    /**
     * @dev after the base assets and single sided rewards have been deposited by holders,
     * and the community has added their side, it is time for the protocol to fund the LP position
     * on the external AMM they selected. In this case the price was determined in advance since
     * there is no liquidity in the AMM for this pairing yet
     * TODO consider a new pair that has liquidity on another AMM which would function more like the
     * other createLiquidity method
     */
    function createInitialLiquidity() external onlyHolder lpFundingWindow {
        Validate.liquidityLaunch(vAmmInfo.hasLaunchPhase);

        address poolAddress = deployPool();

        (, , uint256 numInvTokensFee, uint256 numBaseTokensFee) = addInitialLiquidity();
        saveDepositData(poolAddress);

        aelinFees(numInvTokensFee, numBaseTokensFee);
    }

    /**
     * @dev after the base assets and single sided rewards have been deposited by holders,
     * and the community has added their side, it is time for the protocol to fund the LP position
     * on the external AMM they selected. In this case the price was not determined in advance since
     * there is liquidity in the AMM for this pairing
     * @param _extraBaseTokens is when the price of a token goes down and there are not enough tokens
     * in the contract to match the paired asset e.g. SNX/sUSD is at 5:1 when the pool is created but
     * goes down to 1:1. A pool raising 500K sUSD only needed 100K SNX but now it can take up to 500K
     * so the _extraBaseTokens is eligible from 0 to 400K, whatever additional amount the protocol wants
     * to deposit and match at this time. Leftover sUSD is sent back to community members pro-rata
     */
    function createLiquidity(uint256 _extraBaseTokens) external onlyHolder lpFundingWindow {
        address baseToken = vAmmInfo.ammData.baseToken;

        Validate.notLiquidityLaunch(vAmmInfo.hasLaunchPhase);
        uint256 currentRatio = getPriceRatio();

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
            // TODO use in events
        }

        (, , uint256 numInvTokensFee, uint256 numBaseTokensFee) = addLiquidity();
        saveDepositData(vAmmInfo.poolAddress);

        aelinFees(numInvTokensFee, numBaseTokensFee);
    }

    /**
     * @dev a helper function to calculate the max number of excess base tokens allowed based on price changes
     */
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

    /**
     * @dev saving the important LP deposit data such as pool address, balance of LP and time deposited
     */
    function saveDepositData(address _poolAddress) internal {
        depositData = DepositData(_poolAddress, IERC20(_poolAddress).balanceOf(address(this)), block.timestamp);
    }

    /////////////////////
    // Withdraw Excess //
    /////////////////////

    /**
     * @dev a helper function to send fees to Aelin DAO Multisig and AELIN stakers
     */
    function withdrawExcessFunding() public lpComplete {
        uint256 excessBaseAmount = vAmmInfo.lpVestingSchedule.totalBaseTokens -
            ((vAmmInfo.lpVestingSchedule.totalBaseTokens * totalInvTokensDeposited) / maxInvTokens);
        IERC20(vAmmInfo.ammData.baseToken).safeTransferFrom(address(this), vAmmInfo.mainHolder, excessBaseAmount);

        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = vAmmInfo.singleVestingSchedules[i];

            uint256 excessSingleAmount = singleVestingSchedule.totalSingleTokens -
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

    /**
     * @dev a helper function for community depositors who want to withdraw their funds when
     * the LP tokens are never deposited within the LP funding window
     * @param _tokenIds an array of NFT IDs that represent the community deposits minted when calling acceptDeal
     */
    function depositorWithdraw(uint256[] calldata _tokenIds) external neverDeposited {
        for (uint256 i; i < _tokenIds.length; i++) {
            Validate.isOwner(ownerOf(_tokenIds[i]) == msg.sender);
            VestVestingToken memory schedule = vestingDetails[_tokenIds[i]];
            IERC20(vAmmInfo.ammData.investmentToken).safeTransferFrom(address(this), msg.sender, schedule.amountDeposited);
            emit Withdraw(msg.sender, schedule.amountDeposited);
        }
    }

    ///////////
    // Claim //
    ///////////

    /**
     * @dev allows a user to claim their all their vested tokens across a single NFT
     * @param _tokenId the ID of the NFT to claim for
     */
    function claimAllTokens(uint256 _tokenId) public {
        Validate.isOwner(ownerOf(_tokenId) == msg.sender);
        vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        (uint256 lpAmount, address lpAddress) = claimableLPTokens(_tokenId);
        _claimLPTokens(_tokenId, lpAmount, lpAddress);
        for (uint256 i; i < vAmmInfo.singleVestingSchedules.length; i++) {
            (uint256 singleAmount, address singleAddress) = claimableSingleTokens(_tokenId, i);
            _claimSingleTokens(_tokenId, singleAmount, singleAddress, i);
        }
    }

    /**
     * @dev allows a user to claim their all their vested tokens across many NFTs
     * @param _tokenIds the array of NFT IDs to claim for
     */
    function claimAllTokensManyNFTs(uint256[] calldata _tokenIds) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            claimAllTokens(_tokenIds[i]);
        }
    }

    /**
     * @dev a helper function to claim LP tokens
     * @param _tokenId the NFT ID to claim for
     * @param _claimableAmount the amount to claim
     * @param _token the address of the token to claim
     */
    function _claimLPTokens(uint256 _tokenId, uint256 _claimableAmount, address _token) internal {
        // TODO Validate has claimable balance
        totalLPClaimed += _claimableAmount;
        uint256 withdrawAmount = (totalInvTokensDeposited * _claimableAmount) / depositData.lpTokenAmount;
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(withdrawAmount, msg.sender);
        IERC20(_token).safeTransfer(msg.sender, _claimableAmount);
        emit ClaimedToken(_token, msg.sender, _claimableAmount, ClaimType.LP, 1);
    }

    /**
     * @dev a view function to determine how many single sided rewards are available to claim by a NFT holder
     * @param _tokenId the ID of the NFT which holds the rewards
     * @param _singleRewardIndex the index of the single reward to determine how much to claim
     * @return amount number of tokens claimable at this index in the single sided reward array
     * @return tokenAddress address of the token to claim at this index in the single sided reward array
     */
    function claimableSingleTokens(uint256 _tokenId, uint256 _singleRewardIndex) public view returns (uint256, address) {
        if (depositData.lpDepositTime == 0 || _singleRewardIndex >= vAmmInfo.singleVestingSchedules.length) {
            return (0, address(0));
        }
        SingleVestingSchedule memory singleVestingSchedule = vAmmInfo.singleVestingSchedules[_singleRewardIndex];
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        (uint256 vestingCliff, uint256 vestingExpiry, uint256 maxTime) = calcVestTimes(_tokenId);

        if (
            (schedule.lastClaimedAt < maxTime && block.timestamp > vestingCliff) ||
            (singleVestingSchedule.isLiquid && schedule.lastClaimedAt > 0)
        ) {
            uint256 minTime = schedule.lastClaimedAt == 0 ? vestingCliff : schedule.lastClaimedAt;

            uint256 totalShare = (singleVestingSchedule.totalSingleTokens * schedule.amountDeposited) /
                totalInvTokensDeposited;

            uint256 claimableAmount = (vAmmInfo.lpVestingSchedule.vestingPeriod == 0 || singleVestingSchedule.isLiquid)
                ? totalShare
                : (totalShare * (maxTime - minTime)) / vAmmInfo.lpVestingSchedule.vestingPeriod;

            uint256 precisionAdjustedClaimable = tokensClaimable >
                IERC20(singleVestingSchedule.rewardToken).balanceOf(address(this))
                ? IERC20(singleVestingSchedule.rewardToken).balanceOf(address(this))
                : tokensClaimable;

            return (precisionAdjustedClaimable, singleVestingSchedule.rewardToken);
        }
        return (0, singleVestingSchedule.rewardToken);
    }

    /**
     * @dev a view function to determine how many LP tokens are available to claim by a NFT holder
     * @param _tokenId the ID of the NFT which holds the rewards
     * @return amount number of LP tokens claimable
     * @return tokenAddress address of the LP token to claim
     */
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

    /**
     * @dev a helper function to retrieve and calculate vesting schedule related times for claiming functions
     */
    function calcVestTimes(
        uint256 _tokenId
    ) internal view returns (uint256 vestingCliff, uint256 vestingExpiry, uint256 maxTime) {
        //VestVestingToken memory schedule = vestingDetails[_tokenId];
        //LPVestingSchedule memory lpVestingSchedule = vAmmInfo.lpVestingSchedule;

        vestingCliff = depositData.lpDepositTime + vAmmInfo.lpVestingSchedule.vestingCliffPeriod;
        vestingExpiry = vestingCliff + vAmmInfo.lpVestingSchedule.vestingPeriod;
        maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
    }

    /**
     * @dev allows a user to claim their all their rewards from the VestAMMMultiRewards contract
     * the VestAMMMultiRewards contract allows a protocol to continue sending rewards of various tokens
     * and amounts to LPs who are locked in the contract.
     * @param _tokenId the ID of the NFT to claim for
     */
    function claimMultiRewards(uint256 _tokenId) external {
        // TODO build out claim multi functionality
        //_claimSingleTokens(_tokenId, );
    }

    /**
     * @dev a helper function to claim single sided rewards
     * @param _tokenId the NFT ID to claim for
     * @param _claimableAmount the amount to claim
     * @param _token the address of the token to claim
     * @param _singleRewardsIndex the index of the token to claim in the single sided reward array
     */
    function _claimSingleTokens(
        uint256 _tokenId,
        uint256 _claimableAmount,
        address _token,
        uint256 _singleRewardsIndex
    ) internal {
        Validate.isOwner(ownerOf(_tokenId) == msg.sender);
        Validate.hasClaimBalance(_claimableAmount > 0);
        totalSingleClaimed[_token] += _claimableAmount;
        IERC20(_token).safeTransfer(msg.sender, _claimableAmount);
        emit ClaimedToken(_token, msg.sender, _claimableAmount, ClaimType.Single, uint8(_singleRewardsIndex));
    }

    //////////////
    // Transfer //
    //////////////

    /**
     * @dev a helper function to transfer vesting shares tied to a NFT.
     * NOTE since there is the VestAMMMultiRewards contract, it needs to be updated so that locked
     * LPs who are rewarded by protocols are updated accordingly inside the rewards contract as well
     * @param _to the receiving address
     * @param _tokenId the NFT which is sending a share of its vesting schedule
     * @param _shareAmount the amount of the share to send
     */
    function transferVestingShare(address _to, uint256 _tokenId, uint256 _shareAmount) external {
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(_shareAmount, msg.sender);
        VestAMMMultiRewards(vestAmmMultiRewards).stake(_shareAmount, _to);
        _transferVestingShare(_to, _tokenId, _shareAmount);
    }

    /**
     * @dev a helper function to transfer all the vesting shares tied to a NFT.
     * NOTE since there is the VestAMMMultiRewards contract, it needs to be updated so that locked
     * LPs who are rewarded by protocols are updated accordingly inside the rewards contract as well
     * @param _to the receiving address
     * @param _tokenId the NFT which is sending all shares of its vesting schedule
     */
    function transfer(address _to, uint256 _tokenId) external {
        VestVestingToken memory schedule = vestingDetails[_tokenId];
        VestAMMMultiRewards(vestAmmMultiRewards).amountExit(schedule.amountDeposited, msg.sender);
        VestAMMMultiRewards(vestAmmMultiRewards).stake(schedule.amountDeposited, _to);
        _transfer(_to, _tokenId, "");
    }

    //////////
    // Fees //
    //////////

    /**
     * @dev a helper function to send fees to Aelin DAO Multisig and AELIN stakers
     */
    function aelinFees(uint256 _invTokenFeeAmt, uint256 _baseTokenFeeAmt) internal {
        sendFeesToAelin(vAmmInfo.ammData.baseToken, _baseTokenFeeAmt);

        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            SingleVestingSchedule memory singleVestingSchedule = vAmmInfo.singleVestingSchedules[i];

            uint256 singleRewardsUsed = (singleVestingSchedule.totalSingleTokens * totalInvTokensDeposited) / maxInvTokens;

            uint256 feeAmount = (singleRewardsUsed * VEST_ASSET_FEE) / VEST_BASE_FEE;
            sendFeesToAelin(singleVestingSchedule.rewardToken, feeAmount);
        }
    }

    /**
     * @dev a helper function to send fees to Aelin DAO Multisig and AELIN stakers
     */
    function sendFeesToAelin(address _token, uint256 _amount) public {
        IERC20(_token).approve(aelinFeeModule, _amount);

        /// @dev AelinFeeModule not built in this branch yet
        //aelinFeeModule.sendFees(_token, _amount);
        emit SentFees(_token, _amount);
    }

    /////////////
    // Helpers //
    /////////////

    /**
     * @dev a helper function telling a single rewards holder which rewards
     * they still needs to deposit in the initial phase of the VestAMM deal
     * @param _singleHolder the single sided reward holder
     */
    function singleRewardsToDeposit(address _singleHolder) external view returns (DepositToken[] memory) {
        DepositToken[] memory rewardsToDeposit = new DepositToken[](vAmmInfo.singleVestingSchedules.length);
        for (uint8 i = 0; i < vAmmInfo.singleVestingSchedules.length; i++) {
            address singleHolder = vAmmInfo.singleVestingSchedules[i].singleHolder;
            if (_singleHolder == singleHolder && !vAmmInfo.singleVestingSchedules[i].finalizedDeposit) {
                uint256 amountDeposited = holderDeposits[singleHolder][i];
                DepositToken memory rewardToDeposit = DepositToken(
                    i,
                    vAmmInfo.singleVestingSchedules[i].rewardToken,
                    vAmmInfo.singleVestingSchedules[i].totalSingleTokens - amountDeposited
                );
                rewardsToDeposit[i] = rewardToDeposit;
            }
        }
        return rewardsToDeposit;
    }

    ///////////
    // Hooks //
    ///////////

    function init() internal virtual returns (bool) {}

    function checkPoolExists() internal virtual returns (bool) {}

    function getPriceRatio() internal virtual returns (uint256) {}

    function deployPool() internal virtual returns (address) {}

    function addLiquidity() internal virtual returns (uint256, uint256, uint256, uint256) {}

    function addInitialLiquidity() internal virtual returns (uint256, uint256, uint256, uint256) {}

    function removeLiquidity(uint256 _tokensAmtsIn) internal virtual returns (uint256, uint256) {}

    // TODO Add claim unique LP rewards also

    ///////////////
    // Modifiers //
    ///////////////

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
        Validate.inFundingWindow(depositComplete && block.timestamp > depositExpiry && block.timestamp <= lpFundingExpiry);
        _;
    }

    modifier lpComplete() {
        Validate.fundingComplete(depositData.lpDepositTime > 0);
        _;
    }

    modifier acceptDealOpen() {
        Validate.notCancelled(!isCancelled);
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
