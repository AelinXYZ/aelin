// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinVestingToken.sol";
import "./interfaces/IAelinDeal.sol";
import "./MinimalProxyFactory.sol";
import "./AelinFeeEscrow.sol";

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
    mapping(address => uint256) public amountVested;

    Timeline public openRedemption;
    Timeline public proRataRedemption;

    /**
     * @dev the constructor will always be blank due to the MinimalProxyFactory pattern
     * this allows the underlying logic of this contract to only be deployed once
     * and each new deal created is simply a storage wrapper
     */
    constructor() {}

    /**
     * @dev the initialize method replaces the constructor setup and can only be called once
     * NOTE the deal tokens wrapping the underlying are always 18 decimals
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

        /**
         * calculates the amount of underlying deal tokens you get per wrapped deal token accepted
         */
        underlyingPerDealExchangeRate = (_dealData.underlyingDealTokenTotal * 1e18) / maxTotalSupply;
        emit SetHolder(_dealData.holder);
    }

    /**
     * @dev the holder finalizes the deal for the pool created by the
     * sponsor by depositing funds using this method.
     *
     * NOTE if the deposit was completed with a transfer instead of this method
     * the deposit still needs to be finalized by calling this method with
     * _underlyingDealTokenAmount set to 0
     */
    function depositUnderlying(uint256 _underlyingDealTokenAmount) external finalizeDeposit nonReentrant returns (bool) {
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
     * @dev the holder can withdraw any amount accidentally deposited over
     * the amount needed to fulfill the deal or all amount if deposit was not completed
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
     * @dev after the redemption period has ended the holder can withdraw
     * the excess funds remaining from purchasers who did not accept the deal
     *
     * Requirements:
     * - both the pro rata and open redemption windows are no longer active
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
     * @dev a view showing the number of claimable underlying deal
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
                uint256 underlyingClaimable = vestingPeriod == 0
                    ? schedule.share
                    : (schedule.share * (maxTime - minTime)) / vestingPeriod;

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

    function claimUnderlyingMultipleEntries(uint256[] memory _indices) external {
        for (uint256 i = 0; i < _indices.length; i++) {
            _claimUnderlyingTokens(msg.sender, _indices[i]);
        }
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
        emit ClaimedUnderlyingDealToken(_owner, _tokenId, underlyingDealToken, claimableAmount);
    }

    /**
     * @dev allows the purchaser to mint deal tokens. this method is also used
     * to send deal tokens to the sponsor. It may only be called from the pool
     * contract that created this deal
     */
    function mintVestingToken(address _to, uint256 _amount) external depositCompleted onlyPool {
        totalUnderlyingAccepted += _amount;
        _mintVestingToken(_to, _amount, vestingCliffExpiry);
    }

    /**
     * @dev allows the protocol to handle protocol fees coming in deal tokens.
     * It may only be called from the pool contract that created this deal
     */
    function transferProtocolFee(uint256 dealTokenAmount) external depositCompleted onlyPool {
        uint256 underlyingProtocolFees = (underlyingPerDealExchangeRate * dealTokenAmount) / 1e18;
        IERC20(underlyingDealToken).safeTransfer(address(aelinFeeEscrow), underlyingProtocolFees);
    }

    /**
     * @dev the holder may change their address
     */
    function setHolder(address _holder) external onlyHolder {
        require(_holder != address(0), "holder cant be null");
        futureHolder = _holder;
    }

    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit SetHolder(futureHolder);
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
