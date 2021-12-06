// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinDeal is AelinERC20 {
    using SafeERC20 for IERC20;
    uint256 public maxTotalSupply;

    address public underlyingDealToken;
    uint256 public underlyingDealTokenTotal;
    uint256 public totalUnderlyingClaimed;
    address public holder;
    address public futureHolder;

    uint256 public underlyingPerDealExchangeRate;

    address public aelinPool;
    uint256 public vestingCliff;
    uint256 public vestingPeriod;
    uint256 public vestingExpiry;
    uint256 public holderFundingExpiry;

    uint256 public proRataRedemptionPeriod;
    uint256 public proRataRedemptionStart;
    uint256 public proRataRedemptionExpiry;

    uint256 public openRedemptionPeriod;
    uint256 public openRedemptionStart;
    uint256 public openRedemptionExpiry;

    bool public calledInitialize;
    bool public depositComplete;
    mapping(address => uint256) public amountVested;

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
        string memory _name,
        string memory _symbol,
        address _underlyingDealToken,
        uint256 _underlyingDealTokenTotal,
        uint256 _vestingPeriod,
        uint256 _vestingCliff,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        address _holder,
        uint256 _maxDealTotalSupply,
        uint256 _holderFundingDuration
    ) external initOnce {
        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aeDeal-", _name)),
            string(abi.encodePacked("aeD-", _symbol)),
            DEAL_TOKEN_DECIMALS
        );

        holder = _holder;
        underlyingDealToken = _underlyingDealToken;
        underlyingDealTokenTotal = _underlyingDealTokenTotal;
        maxTotalSupply = _maxDealTotalSupply;

        aelinPool = msg.sender;
        vestingCliff =
            block.timestamp +
            _proRataRedemptionPeriod +
            _openRedemptionPeriod +
            _vestingCliff;
        vestingPeriod = _vestingPeriod;
        vestingExpiry = vestingCliff + _vestingPeriod;
        proRataRedemptionPeriod = _proRataRedemptionPeriod;
        openRedemptionPeriod = _openRedemptionPeriod;
        holderFundingExpiry = _holderFundingDuration;

        depositComplete = false;

        /**
         * calculates the amount of underlying deal tokens you get per wrapped deal token accepted
         */
        underlyingPerDealExchangeRate =
            (_underlyingDealTokenTotal * 1e18) /
            maxTotalSupply;
        emit SetHolder(_holder);
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

    /**
     * @dev the holder may change their address
     */
    function setHolder(address _holder) external onlyHolder {
        futureHolder = _holder;
    }

    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit SetHolder(futureHolder);
    }

    /**
     * @dev the holder finalizes the deal for the pool created by the
     * sponsor by depositing funds using this method.
     *
     * NOTE if the deposit was completed with a transfer instead of this method
     * the deposit still needs to be finalized by calling this method with
     * _underlyingDealTokenAmount set to 0
     */
    function depositUnderlying(uint256 _underlyingDealTokenAmount)
        external
        finalizeDeposit
        lock
        returns (bool)
    {
        if (_underlyingDealTokenAmount > 0) {
            uint256 currentBalance = IERC20(underlyingDealToken).balanceOf(
                address(this)
            );
            IERC20(underlyingDealToken).safeTransferFrom(
                msg.sender,
                address(this),
                _underlyingDealTokenAmount
            );
            uint256 balanceAfterTransfer = IERC20(underlyingDealToken)
                .balanceOf(address(this));
            uint256 underlyingDealTokenAmount = balanceAfterTransfer -
                currentBalance;

            emit DepositDealToken(
                underlyingDealToken,
                msg.sender,
                underlyingDealTokenAmount
            );
        }

        if (
            IERC20(underlyingDealToken).balanceOf(address(this)) >=
            underlyingDealTokenTotal
        ) {
            depositComplete = true;
            proRataRedemptionStart = block.timestamp;
            proRataRedemptionExpiry = block.timestamp + proRataRedemptionPeriod;

            if (openRedemptionPeriod > 0) {
                openRedemptionStart = proRataRedemptionExpiry;
                openRedemptionExpiry =
                    proRataRedemptionExpiry +
                    openRedemptionPeriod;
            }
            emit DealFullyFunded(
                aelinPool,
                proRataRedemptionStart,
                proRataRedemptionExpiry,
                openRedemptionStart,
                openRedemptionExpiry
            );
            return true;
        }
        return false;
    }

    /**
     * @dev the holder can withdraw any amount accidentally deposited over
     * the amount needed to fulfill the deal
     *
     * NOTE if the deposit was completed with a transfer instead of this method
     * the deposit still needs to be finalized by calling this method with
     * _underlyingDealTokenAmount set to 0
     */
    function withdraw() external onlyHolder {
        uint256 withdrawAmount;
        if (!depositComplete && block.timestamp >= holderFundingExpiry) {
            withdrawAmount = IERC20(underlyingDealToken).balanceOf(
                address(this)
            );
        } else {
            withdrawAmount =
                IERC20(underlyingDealToken).balanceOf(address(this)) -
                (underlyingDealTokenTotal - totalUnderlyingClaimed);
        }
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealToken(
            underlyingDealToken,
            holder,
            withdrawAmount
        );
    }

    /**
     * @dev after the redemption period has ended the holder can withdraw
     * the excess funds remaining from purchasers who did not accept the deal
     *
     * Requirements:
     * - both the pro rata and open redemption windows are no longer active
     */
    function withdrawExpiry() external onlyHolder {
        require(proRataRedemptionExpiry > 0, "redemption period not started");
        require(
            openRedemptionExpiry > 0
                ? block.timestamp >= openRedemptionExpiry
                : block.timestamp >= proRataRedemptionExpiry,
            "redeem window still active"
        );
        uint256 withdrawAmount = IERC20(underlyingDealToken).balanceOf(
            address(this)
        ) - ((underlyingPerDealExchangeRate * totalSupply()) / 1e18);
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealToken(
            underlyingDealToken,
            holder,
            withdrawAmount
        );
    }

    modifier onlyHolder() {
        require(msg.sender == holder, "only holder can access");
        _;
    }

    modifier onlyPool() {
        require(msg.sender == aelinPool, "only AelinPool can access");
        _;
    }

    /**
     * @dev a view showing the number of claimable deal tokens and the
     * amount of the underlying deal token a purchser gets in return
     */
    function claimableTokens(address purchaser)
        public
        view
        returns (uint256 underlyingClaimable, uint256 dealTokensClaimable)
    {
        underlyingClaimable = 0;
        dealTokensClaimable = 0;
        uint256 maxTime = block.timestamp > vestingExpiry
            ? vestingExpiry
            : block.timestamp;
        if (
            balanceOf(purchaser) > 0 &&
            (maxTime > vestingCliff ||
                (maxTime == vestingCliff && vestingPeriod == 0))
        ) {
            uint256 timeElapsed = maxTime - vestingCliff;
            dealTokensClaimable = vestingPeriod == 0
                ? balanceOf(purchaser)
                : ((balanceOf(purchaser) + amountVested[purchaser]) *
                    timeElapsed) /
                    vestingPeriod -
                    amountVested[purchaser];
            underlyingClaimable =
                (underlyingPerDealExchangeRate * dealTokensClaimable) /
                1e18;
        }
    }

    /**
     * @dev allows a user to claim their underlying deal tokens or a partial amount
     * of their underlying tokens once they have vested according to the schedule
     * created by the sponsor
     */
    function claim() external returns (uint256) {
        return _claim(msg.sender);
    }

    function _claim(address recipient) internal returns (uint256) {
        (
            uint256 underlyingDealTokensClaimed,
            uint256 dealTokensClaimed
        ) = claimableTokens(recipient);
        if (dealTokensClaimed > 0) {
            amountVested[recipient] += dealTokensClaimed;
            _burn(recipient, dealTokensClaimed);
            IERC20(underlyingDealToken).safeTransfer(
                recipient,
                underlyingDealTokensClaimed
            );
            totalUnderlyingClaimed += underlyingDealTokensClaimed;
            emit ClaimedUnderlyingDealToken(
                underlyingDealToken,
                recipient,
                underlyingDealTokensClaimed
            );
        }
        return dealTokensClaimed;
    }

    /**
     * @dev allows the purchaser to mint deal tokens. this method is also used
     * to send deal tokens to the sponsor and the aelin rewards pool. It may only
     * be called from the pool contract that created this deal
     */
    function mint(address dst, uint256 dealTokenAmount) external onlyPool {
        require(depositComplete, "deposit not complete");
        _mint(dst, dealTokenAmount);
    }

    /**
     * @dev deal tokens cant be transferred after the vesting expiry since
     * all tokens will be claimed at the start of the transfer leaving 0 to send
     */
    modifier transferWindow() {
        require(
            vestingExpiry > block.timestamp,
            "no transfers after vest done"
        );
        _;
    }

    /**
     * @dev below are helpers for transferring deal tokens. NOTE the token holder transferring
     * the deal tokens must pay the gas to claim their vested tokens first, which will burn their vested deal
     * tokens. They must also pay for the receivers claim and burn any of their vested tokens in order to ensure
     * the claim calculation is always accurate for all parties in the system
     */
    function transferMax(address recipient) external returns (bool) {
        (, uint256 claimableDealTokens) = claimableTokens(msg.sender);
        return transfer(recipient, balanceOf(msg.sender) - claimableDealTokens);
    }

    function transferFromMax(address sender, address recipient)
        external
        returns (bool)
    {
        (, uint256 claimableDealTokens) = claimableTokens(sender);
        return
            transferFrom(
                sender,
                recipient,
                balanceOf(sender) - claimableDealTokens
            );
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        transferWindow
        returns (bool)
    {
        _claim(msg.sender);
        _claim(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override transferWindow returns (bool) {
        _claim(sender);
        _claim(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    event SetHolder(address indexed holder);
    event DealFullyFunded(
        address indexed poolAddress,
        uint256 proRataRedemptionStart,
        uint256 proRataRedemptionExpiry,
        uint256 openRedemptionStart,
        uint256 openRedemptionExpiry
    );
    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
    event WithdrawUnderlyingDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
    event ClaimedUnderlyingDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed recipient,
        uint256 underlyingDealTokensClaimed
    );
}
