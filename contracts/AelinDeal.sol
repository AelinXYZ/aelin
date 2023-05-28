// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AelinFeeEscrow} from "./AelinFeeEscrow.sol";
import {AelinVestingToken} from "./AelinVestingToken.sol";
import {MinimalProxyFactory} from "./MinimalProxyFactory.sol";
import {IAelinDeal} from "./interfaces/IAelinDeal.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinDeal is AelinVestingToken, MinimalProxyFactory, IAelinDeal {
    using SafeERC20 for IERC20;
    uint256 public maxTotalSupply;

    address public underlyingDealToken;
    uint256 public underlyingDealTokenTotal;
    uint256 public totalUnderlyingAccepted;
    uint256 public totalUnderlyingClaimed;
    address public holder;
    address public futureHolder;
    address public aelinTreasuryAddress;

    uint256 public underlyingPerDealExchangeRate;

    address public aelinPool;
    uint256 public vestingCliffExpiry;
    uint256 public vestingCliffPeriod;
    uint256 public vestingPeriod;
    uint256 public vestingExpiry;
    uint256 public holderFundingExpiry;

    bool private calledInitialize;
    address public aelinEscrowAddress;
    AelinFeeEscrow public aelinFeeEscrow;

    bool public depositComplete;

    Timeline public openRedemption;
    Timeline public proRataRedemption;

    /**
     * NOTE The deal tokens wrapping the underlying are always 18 decimals.
     */
    function initialize(
        string calldata _poolName,
        string calldata _poolSymbol,
        DealData calldata _dealData,
        address _aelinTreasuryAddress,
        address _aelinEscrowAddress
    ) external initOnce {
        _setNameAndSymbol(string(abi.encodePacked("aeDeal-", _poolName)), string(abi.encodePacked("aeD-", _poolSymbol)));

        holder = _dealData.holder;
        underlyingDealToken = _dealData.underlyingDealToken;
        underlyingDealTokenTotal = _dealData.underlyingDealTokenTotal;
        maxTotalSupply = _dealData.maxDealTotalSupply;

        aelinPool = msg.sender;
        vestingCliffPeriod = _dealData.vestingCliffPeriod;
        vestingPeriod = _dealData.vestingPeriod;
        proRataRedemption.period = _dealData.proRataRedemptionPeriod;
        openRedemption.period = _dealData.openRedemptionPeriod;
        holderFundingExpiry = _dealData.holderFundingDuration;
        aelinTreasuryAddress = _aelinTreasuryAddress;
        aelinEscrowAddress = _aelinEscrowAddress;

        depositComplete = false;

        // Calculates the amount of underlying deal tokens you get per wrapped deal token accepted
        underlyingPerDealExchangeRate = (_dealData.underlyingDealTokenTotal * 1e18) / maxTotalSupply;
        emit HolderAccepted(_dealData.holder);
    }

    /**
     * @notice This function allows the holder to deposit any amount of underlying deal tokens to a pool.
     * If the cumulative deposited amount is greater than the underlyingDealTokenTotal the deal is finalized.
     * @param _underlyingDealTokenAmount The amount of underlying deal tokens deposited.
     * @return bool Returns true if the cumulative deposited amount is greater than the underlyingDealTokenTotal,
     * meaning that the deal is full funded and finalized. Returns false otherwise.
     * NOTE If the deposit was completed with a transfer instead of this method the deposit still needs to
     * be finalized by calling this method with _underlyingDealTokenAmount set to 0.
     */
    function depositUnderlying(
        uint256 _underlyingDealTokenAmount
    ) external finalizeDeposit onlyHolder nonReentrant returns (bool) {
        if (_underlyingDealTokenAmount > 0) {
            uint256 currentBalance = IERC20(underlyingDealToken).balanceOf(address(this));
            IERC20(underlyingDealToken).safeTransferFrom(msg.sender, address(this), _underlyingDealTokenAmount);
            uint256 balanceAfterTransfer = IERC20(underlyingDealToken).balanceOf(address(this));
            uint256 underlyingDealTokenAmount = balanceAfterTransfer - currentBalance;

            emit DepositDealToken(underlyingDealToken, msg.sender, underlyingDealTokenAmount);
        }

        if (IERC20(underlyingDealToken).balanceOf(address(this)) >= underlyingDealTokenTotal) {
            depositComplete = true;
            proRataRedemption.start = block.timestamp;
            proRataRedemption.expiry = block.timestamp + proRataRedemption.period;
            vestingCliffExpiry = block.timestamp + proRataRedemption.period + openRedemption.period + vestingCliffPeriod;
            vestingExpiry = vestingCliffExpiry + vestingPeriod;

            if (openRedemption.period > 0) {
                openRedemption.start = proRataRedemption.expiry;
                openRedemption.expiry = proRataRedemption.expiry + openRedemption.period;
            }

            address aelinEscrowStorageProxy = _cloneAsMinimalProxy(aelinEscrowAddress, "Could not create new escrow");
            aelinFeeEscrow = AelinFeeEscrow(aelinEscrowStorageProxy);
            aelinFeeEscrow.initialize(aelinTreasuryAddress, underlyingDealToken);

            emit DealFullyFunded(
                aelinPool,
                proRataRedemption.start,
                proRataRedemption.expiry,
                openRedemption.start,
                openRedemption.expiry
            );
            return true;
        }
        return false;
    }

    /**
     * @notice This function allows the holder to withdraw any amount of underlying tokens accidently
     * deposited over the amount needed to fulfill the deal, or all of the amount deposited if the deal
     * was not completed.
     */
    function withdraw() external onlyHolder {
        uint256 withdrawAmount;
        if (!depositComplete && block.timestamp >= holderFundingExpiry) {
            withdrawAmount = IERC20(underlyingDealToken).balanceOf(address(this));
        } else {
            withdrawAmount =
                IERC20(underlyingDealToken).balanceOf(address(this)) -
                (underlyingDealTokenTotal - totalUnderlyingClaimed);
        }
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealToken(underlyingDealToken, holder, withdrawAmount);
    }

    /**
     * @notice This function allows the holder to withdraw any excess underlying deal tokens after
     * the the redemption period has ended.
     * NOTE Both the pro rata and open redemption windows must no longer be active.
     */
    function withdrawExpiry() external onlyHolder {
        require(proRataRedemption.expiry > 0, "redemption period not started");
        require(
            openRedemption.expiry > 0
                ? block.timestamp >= openRedemption.expiry
                : block.timestamp >= proRataRedemption.expiry,
            "redeem window still active"
        );
        uint256 withdrawAmount = IERC20(underlyingDealToken).balanceOf(address(this)) -
            ((underlyingPerDealExchangeRate * totalUnderlyingAccepted) / 1e18);
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealToken(underlyingDealToken, holder, withdrawAmount);
    }

    /**
     * @notice This view function returns the number of claimable underlying deal tokens given the token id
     * of a user's vesting token.
     * @param _tokenId The token id of a user's vesting token.
     * @return uint256 The number of underlying deal tokens a user can claim.
     */
    function claimableUnderlyingTokens(uint256 _tokenId) public view returns (uint256) {
        VestingDetails memory schedule = vestingDetails[_tokenId];
        uint256 precisionAdjustedUnderlyingClaimable;

        if (schedule.lastClaimedAt > 0) {
            uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
            uint256 minTime = schedule.lastClaimedAt > vestingCliffExpiry ? schedule.lastClaimedAt : vestingCliffExpiry;

            if (
                (maxTime > vestingCliffExpiry && minTime <= vestingExpiry) ||
                (maxTime == vestingCliffExpiry && vestingPeriod == 0)
            ) {
                uint256 claimableAmount = vestingPeriod == 0
                    ? schedule.share
                    : (schedule.share * (maxTime - minTime)) / vestingPeriod;
                uint256 underlyingClaimable = (underlyingPerDealExchangeRate * claimableAmount) / 1e18;

                /**
                 * @dev There could potentially be the case where the last user claims a slightly smaller amount
                 * if there is some precision loss, although it will generally never happen as solidity rounds
                 * down so there should always be a little bit left.
                 */
                precisionAdjustedUnderlyingClaimable = underlyingClaimable >
                    IERC20(underlyingDealToken).balanceOf(address(this))
                    ? IERC20(underlyingDealToken).balanceOf(address(this))
                    : underlyingClaimable;
            }
        }
        return precisionAdjustedUnderlyingClaimable;
    }

    /**
     * @notice This function allows a user to claim their underlying deal tokens, or a partial amount of their
     * underlying tokens, from multiple vesting tokens once they have vested according to the schedule created
     * by the sponsor.
     * @param _indices The token ids of a user's vesting tokens.
     * @return uint256 The number of underlying deal tokens a user claimed.
     * NOTE If the vesting of any token ids has been completed the corresponding vesting token will be burned.
     */
    function claimUnderlyingMultipleEntries(uint256[] memory _indices) external returns (uint256) {
        uint256 totalClaimed;
        for (uint256 i = 0; i < _indices.length; i++) {
            totalClaimed += _claimUnderlyingTokens(msg.sender, _indices[i]);
        }
        return totalClaimed;
    }

    /**
     * @notice This function allows a user to claim their underlying deal tokens, or a partial amount of their
     * underlying tokens, once they have vested according to the schedule created by the sponsor.
     * @param _tokenId The token id of a user's vesting token.
     * @return uint256 The number of underlying deal tokens a user claimed.
     * NOTE If the vesting has been completed the vesting token will be burned.
     */
    function claimUnderlyingTokens(uint256 _tokenId) external returns (uint256) {
        return _claimUnderlyingTokens(msg.sender, _tokenId);
    }

    function _claimUnderlyingTokens(address _owner, uint256 _tokenId) internal returns (uint256) {
        require(ownerOf(_tokenId) == _owner, "must be owner to claim");
        uint256 claimableAmount = claimableUnderlyingTokens(_tokenId);
        if (claimableAmount == 0) {
            return 0;
        }
        if (block.timestamp >= vestingExpiry) {
            _burnVestingToken(_tokenId);
        } else {
            vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        }
        totalUnderlyingClaimed += claimableAmount;
        IERC20(underlyingDealToken).safeTransfer(_owner, claimableAmount);
        emit ClaimedUnderlyingDealToken(_owner, _tokenId, underlyingDealToken, claimableAmount);
        return claimableAmount;
    }

    /**
     * @notice This function allows the purchaser to mint deal tokens. It is also used to send deal tokens to
     * the sponsor.
     * @param _to The recipient of the vesting token.
     * @param _amount The number of vesting tokens to be minted.
     * NOTE It may only be called from the pool contract that created this deal, and only after the deposit has
     * been completed.
     */
    function mintVestingToken(address _to, uint256 _amount) external depositCompleted onlyPool {
        totalUnderlyingAccepted += _amount;
        /**
         * @dev Vesting index hard-coded to zero here. Multiple vesting schedules currently not supported
         * for these deals.
         */
        _mintVestingToken(_to, _amount, vestingCliffExpiry, 0);
    }

    /**
     * @notice This function allows the protocol to handle protocol fees, with deal tokens.
     * @param _dealTokenAmount The number of deal tokens reserved for protocol fees.
     * NOTE It may only be called from the pool contract that created this deal, and only after the deposit has
     * been completed.
     */
    function transferProtocolFee(uint256 _dealTokenAmount) external depositCompleted onlyPool {
        uint256 underlyingProtocolFees = (underlyingPerDealExchangeRate * _dealTokenAmount) / 1e18;
        IERC20(underlyingDealToken).safeTransfer(address(aelinFeeEscrow), underlyingProtocolFees);
    }

    /**
     * @notice This function allows the holder to set a future holder address without changing the
     * holder address currently.
     * @param _futureHolder The future holder address.
     */
    function setHolder(address _futureHolder) external onlyHolder {
        require(_futureHolder != address(0), "holder cant be null");
        futureHolder = _futureHolder;
        emit HolderSet(_futureHolder);
    }

    /**
     * @notice This function allows the future holder address to replace the current holder address.
     */
    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit HolderAccepted(futureHolder);
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    modifier finalizeDeposit() {
        require(block.timestamp < holderFundingExpiry, "deposit past deadline");
        require(!depositComplete, "deposit already complete");
        _;
    }

    modifier depositCompleted() {
        require(depositComplete, "deposit not complete");
        _;
    }

    modifier onlyHolder() {
        require(msg.sender == holder, "only holder can access");
        _;
    }

    modifier onlyPool() {
        require(msg.sender == aelinPool, "only AelinPool can access");
        _;
    }
}
