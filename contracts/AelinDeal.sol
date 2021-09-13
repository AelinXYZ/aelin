// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinDeal is AelinERC20 {
    using SafeERC20 for IERC20;
    uint256 public maxTotalSupply;

    address public underlyingDealToken;
    uint256 public underlyingDealTokenDecimals;
    uint256 public underlyingDealTokenTotal;
    uint256 public totalUnderlyingClaimed;
    address public holder;
    address public futureHolder;

    uint256 public underlyingPerPoolExchangeRate;

    address public aelinPool;
    uint256 public vestingCliff;
    uint256 public vestingPeriod;
    uint256 public vestingExpiry;

    uint256 public proRataRedemptionPeriod;
    uint256 public proRataRedemptionStart;
    uint256 public proRataRedemptionExpiry;

    uint256 public openRedemptionPeriod;
    uint256 public openRedemptionStart;
    uint256 public openRedemptionExpiry;

    bool public calledInitialize;
    bool public depositComplete;

    constructor() {}

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
        uint256 _poolTokenMaxPurchaseAmount
    ) external initOnce {
        _setNameAndSymbol(
            string(abi.encodePacked("aeDeal-", _name)),
            string(abi.encodePacked("aeD-", _symbol))
        );

        holder = _holder;
        underlyingDealToken = _underlyingDealToken;
        underlyingDealTokenDecimals = IERC20Decimals(_underlyingDealToken)
            .decimals();
        underlyingDealTokenTotal = _underlyingDealTokenTotal;
        maxTotalSupply = _poolTokenMaxPurchaseAmount;

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

        calledInitialize = true;
        depositComplete = false;

        // NOTE calculate the amount of underlying deal tokens you get per wrapped pool token accepted
        // Also, 1 wrapped pool token = 1 wrapped deal token
        underlyingPerPoolExchangeRate =
            (_underlyingDealTokenTotal * 1e18) /
            _poolTokenMaxPurchaseAmount;
        emit SetHolder(_holder);
    }

    modifier initOnce() {
        require(calledInitialize == false, "can only initialize once");
        _;
    }

    modifier finalizeDepositOnce() {
        require(depositComplete == false, "deposit already complete");
        _;
    }

    function setHolder(address _holder) external onlyHolder {
        futureHolder = _holder;
    }

    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit SetHolder(futureHolder);
    }

    // NOTE if the deposit was completed with a transfer instead of this method,
    // the deposit can be finalized by calling this method with amount 0;
    function depositUnderlying(uint256 _underlyingDealTokenAmount)
        external
        finalizeDepositOnce
        returns (bool)
    {
        if (
            IERC20(underlyingDealToken).balanceOf(address(this)) +
                _underlyingDealTokenAmount >=
            underlyingDealTokenTotal
        ) {
            depositComplete = true;
        }
        if (_underlyingDealTokenAmount > 0) {
            IERC20(underlyingDealToken).safeTransferFrom(
                msg.sender,
                address(this),
                _underlyingDealTokenAmount
            );
            emit DepositDealTokens(
                underlyingDealToken,
                msg.sender,
                address(this),
                _underlyingDealTokenAmount
            );
        }
        if (depositComplete == true) {
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
                address(this),
                proRataRedemptionStart,
                proRataRedemptionExpiry,
                openRedemptionStart,
                openRedemptionExpiry
            );
            return true;
        }
        return false;
    }

    // @NOTE the holder can withdraw any amount accidentally deposited over the amount needed to fulfill the deal
    // TODO the holder can deposit less if people withdraw after the deal is created but before the deal is funded.
    function withdraw() external onlyHolder {
        uint256 withdrawAmount = IERC20(underlyingDealToken).balanceOf(
            address(this)
        ) -
            underlyingDealTokenTotal -
            totalUnderlyingClaimed;
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealTokens(
            underlyingDealToken,
            holder,
            address(this),
            withdrawAmount
        );
    }

    function withdrawExpiry() external onlyHolder {
        require(proRataRedemptionExpiry > 0, "redemption period not started");
        require(
            openRedemptionExpiry > 0
                ? block.timestamp > openRedemptionExpiry
                : block.timestamp > proRataRedemptionExpiry,
            "redeem window still active"
        );
        uint256 withdrawAmount = IERC20(underlyingDealToken).balanceOf(
            address(this)
        ) - ((underlyingPerPoolExchangeRate * totalSupply()) / 1e18);
        IERC20(underlyingDealToken).safeTransfer(holder, withdrawAmount);
        emit WithdrawUnderlyingDealTokens(
            underlyingDealToken,
            holder,
            address(this),
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

    mapping(address => uint256) public lastClaim;

    function underlyingDealTokensClaimable(address purchaser)
        external
        view
        returns (uint256)
    {
        uint256 maxTime = block.timestamp > vestingExpiry
            ? vestingExpiry
            : block.timestamp;
        if (
            maxTime > vestingCliff ||
            (maxTime == vestingCliff &&
                vestingPeriod == 0 &&
                lastClaim[purchaser] == 0)
        ) {
            uint256 lastClaimed = lastClaim[purchaser];
            if (lastClaimed == 0) {
                lastClaimed = vestingCliff;
            }
            if (lastClaimed >= maxTime && vestingPeriod != 0) {
                return 0;
            } else {
                uint256 timeElapsed = maxTime - lastClaimed;
                uint256 dealTokensClaimable = vestingPeriod == 0
                    ? balanceOf(purchaser)
                    : (balanceOf(purchaser) * timeElapsed) / vestingPeriod;
                return
                    (underlyingPerPoolExchangeRate * dealTokensClaimable) /
                    1e18;
            }
        } else {
            return 0;
        }
    }

    function claim() public returns (uint256) {
        _claim(msg.sender);
    }

    function _claim(address recipient) internal returns (uint256) {
        if (balanceOf(recipient) > 0) {
            uint256 maxTime = block.timestamp > vestingExpiry
                ? vestingExpiry
                : block.timestamp;
            if (
                maxTime > vestingCliff ||
                (maxTime == vestingCliff &&
                    vestingPeriod == 0 &&
                    lastClaim[recipient] == 0)
            ) {
                if (lastClaim[recipient] == 0) {
                    lastClaim[recipient] = vestingCliff;
                }
                uint256 timeElapsed = maxTime - lastClaim[recipient];
                uint256 dealTokensClaimed = vestingPeriod == 0
                    ? balanceOf(recipient)
                    : (balanceOf(recipient) * timeElapsed) / vestingPeriod;
                uint256 underlyingDealTokensClaimed = (underlyingPerPoolExchangeRate *
                        dealTokensClaimed) / 1e18;

                if (dealTokensClaimed > 0) {
                    _burn(recipient, dealTokensClaimed);
                    IERC20(underlyingDealToken).safeTransfer(
                        recipient,
                        underlyingDealTokensClaimed
                    );
                    totalUnderlyingClaimed += underlyingDealTokensClaimed;
                    emit ClaimedUnderlyingDealTokens(
                        underlyingDealToken,
                        recipient,
                        underlyingDealTokensClaimed
                    );
                }
                lastClaim[recipient] = maxTime;
                return dealTokensClaimed;
            }
        }
        return 0;
    }

    function mint(address dst, uint256 dealTokenAmount) external onlyPool {
        _mint(dst, dealTokenAmount);
        emit MintDealTokens(address(this), dst, dealTokenAmount);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
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
    ) public virtual override returns (bool) {
        _claim(sender);
        _claim(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    event SetHolder(address indexed holder);
    event DealFullyFunded(
        address indexed poolAddress,
        address indexed dealAddress,
        uint256 proRataRedemptionStart,
        uint256 proRataRedemptionExpiry,
        uint256 openRedemptionStart,
        uint256 openRedemptionExpiry
    );
    event DepositDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        address indexed dealContract,
        uint256 underlyingDealTokenAmount
    );
    event WithdrawUnderlyingDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        address indexed dealContract,
        uint256 underlyingDealTokenAmount
    );
    event ClaimedUnderlyingDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed recipient,
        uint256 underlyingDealTokensClaimed
    );
    event MintDealTokens(
        address indexed dealContract,
        address indexed recipient,
        uint256 dealTokenAmount
    );
}
