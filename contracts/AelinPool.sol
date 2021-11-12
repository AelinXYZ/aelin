// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./MinimalProxyFactory.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory {
    using SafeERC20 for IERC20;
    uint256 constant BASE = 100 * 10**18;
    uint256 constant MAX_SPONSOR_FEE = 98 * 10**18;
    uint256 constant AELIN_FEE = 2 * 10**18;

    address public purchaseToken;
    uint256 public purchaseTokenCap;
    uint8 public purchaseTokenDecimals;
    uint256 public proRataConversion;

    uint256 public sponsorFee;
    address public sponsor;
    address public futureSponsor;

    uint256 public purchaseExpiry;
    uint256 public poolExpiry;
    uint256 public holderFundingExpiry;
    uint256 public totalAmountAccepted;
    uint256 public purchaseTokenTotalForDeal;

    bool public calledInitialize = false;

    address public aelinRewardsAddress;
    address public aelinDealLogicAddress;
    address public aelinDealStorageProxy;
    address public holder;

    mapping(address => uint256) public amountAccepted;
    mapping(address => bool) public openPeriodEligible;

    string private storedName;
    string private storedSymbol;

    /**
     * @dev the constructor will always be blank due to the MinimalProxyFactory pattern
     * this allows the underlying logic of this contract to only be deployed once
     * and each new pool created is simply a storage wrapper
     */
    constructor() {}

    /**
     * @dev the initialize method replaces the constructor setup and can only be called once
     *
     * Requirements:
     * - max 1 year duration
     * - purchase expiry can be set from 30 minutes to 30 days
     * - max sponsor fee is 98000 representing 98%
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _purchaseTokenCap,
        address _purchaseToken,
        uint256 _duration,
        uint256 _sponsorFee,
        address _sponsor,
        uint256 _purchaseExpiry,
        address _aelinDealLogicAddress,
        address _aelinRewardsAddress
    ) external initOnce {
        require(
            30 minutes <= _purchaseExpiry && 30 days >= _purchaseExpiry,
            "outside purchase expiry window"
        );
        require(365 days >= _duration, "max 1 year duration");
        require(_sponsorFee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");
        storedName = _name;
        storedSymbol = _symbol;
        purchaseTokenDecimals = IERC20Decimals(_purchaseToken).decimals();

        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol)),
            purchaseTokenDecimals
        );

        purchaseTokenCap = _purchaseTokenCap;
        purchaseToken = _purchaseToken;
        purchaseExpiry = block.timestamp + _purchaseExpiry;
        poolExpiry = purchaseExpiry + _duration;
        sponsorFee = _sponsorFee;
        sponsor = _sponsor;
        aelinDealLogicAddress = _aelinDealLogicAddress;
        aelinRewardsAddress = _aelinRewardsAddress;
        emit SetSponsor(_sponsor);
    }

    modifier dealReady() {
        if (holderFundingExpiry > 0) {
            require(
                !AelinDeal(aelinDealStorageProxy).depositComplete() &&
                    block.timestamp >= holderFundingExpiry,
                "cant create new deal"
            );
        }
        _;
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    modifier onlySponsor() {
        require(msg.sender == sponsor, "only sponsor can access");
        _;
    }

    modifier dealFunded() {
        require(
            holderFundingExpiry > 0 &&
                AelinDeal(aelinDealStorageProxy).depositComplete(),
            "deal not yet funded"
        );
        _;
    }

    /**
     * @dev the sponsor may change addresses
     */
    function setSponsor(address _sponsor) external onlySponsor {
        futureSponsor = _sponsor;
    }

    function acceptSponsor() external {
        require(msg.sender == futureSponsor, "only future sponsor can access");
        sponsor = futureSponsor;
        emit SetSponsor(futureSponsor);
    }

    /**
     * @dev only the sponsor can create a deal. The deal must be funded by the holder
     * of the underlying deal token before a purchaser may accept the deal. If the
     * holder does not fund the deal before the expiry period is over then the sponsor
     * can create a new deal for the pool of capital by calling this method again.
     *
     * Requirements:
     * - The purchase expiry period must be over
     * - the holder funding expiry period must be from 30 minutes to 30 days
     * - the pro rata redemption period must be from 30 minutes to 30 days
     * - the purchase token total for the deal that may be accepted must be <= the funds in the pool
     * - if the pro rata conversion ratio (purchase token total for the deal:funds in pool)
     *   is 1:1 then the open redemption period must be 0,
     *   otherwise the open period is from 30 minutes to 30 days
     */
    function createDeal(
        address _underlyingDealToken,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _underlyingDealTokenTotal,
        uint256 _vestingPeriod,
        uint256 _vestingCliff,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        address _holder,
        uint256 _holderFundingExpiry
    ) external onlySponsor dealReady returns (address) {
        require(
            block.timestamp >= purchaseExpiry,
            "pool still in purchase mode"
        );
        require(
            30 minutes <= _proRataRedemptionPeriod &&
                30 days >= _proRataRedemptionPeriod,
            "30 mins - 30 days for prorata"
        );
        require(1825 days >= _vestingCliff, "max 5 year cliff");
        require(1825 days >= _vestingPeriod, "max 5 year vesting");
        require(
            30 minutes <= _holderFundingExpiry &&
                30 days >= _holderFundingExpiry,
            "30 mins - 30 days for holder"
        );
        require(
            _purchaseTokenTotalForDeal <= totalSupply(),
            "not enough funds available"
        );
        proRataConversion = (_purchaseTokenTotalForDeal * 1e18) / totalSupply();
        if (proRataConversion == 1e18) {
            require(
                0 minutes == _openRedemptionPeriod,
                "deal is 1:1, set open to 0"
            );
        } else {
            require(
                30 minutes <= _openRedemptionPeriod &&
                    30 days >= _openRedemptionPeriod,
                "30 mins - 30 days for open"
            );
        }

        poolExpiry = block.timestamp;
        holder = _holder;
        holderFundingExpiry = block.timestamp + _holderFundingExpiry;
        purchaseTokenTotalForDeal = _purchaseTokenTotalForDeal;
        uint256 maxDealTotalSupply = convertPoolToDeal(
            _purchaseTokenTotalForDeal,
            purchaseTokenDecimals
        );

        AelinDeal aelinDeal = AelinDeal(
            _cloneAsMinimalProxy(
                aelinDealLogicAddress,
                "Could not create new deal"
            )
        );
        aelinDeal.initialize(
            storedName,
            storedSymbol,
            _underlyingDealToken,
            _underlyingDealTokenTotal,
            _vestingPeriod,
            _vestingCliff,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _holder,
            maxDealTotalSupply,
            holderFundingExpiry
        );
        aelinDealStorageProxy = address(aelinDeal);

        emit CreateDeal(
            string(abi.encodePacked("aeDeal-", storedName)),
            string(abi.encodePacked("aeD-", storedSymbol)),
            sponsor,
            aelinDealStorageProxy
        );

        emit DealDetails(
            aelinDealStorageProxy,
            _underlyingDealToken,
            _purchaseTokenTotalForDeal,
            _underlyingDealTokenTotal,
            _vestingPeriod,
            _vestingCliff,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _holder,
            _holderFundingExpiry
        );

        return aelinDealStorageProxy;
    }

    /**
     * @dev the 2 methods allow a purchaser to exchange accept all or a
     * portion of their pool tokens for deal tokens
     *
     * Requirements:
     * - the redemption period is either in the pro rata or open windows
     * - the purchaser cannot accept more than their share for a period
     * - if participating in the open period, a purchaser must have maxxed their
     *   contribution in the pro rata phase
     */
    function acceptMaxDealTokens() external {
        _acceptDealTokens(msg.sender, 0, true);
    }

    function acceptDealTokens(uint256 poolTokenAmount) external {
        _acceptDealTokens(msg.sender, poolTokenAmount, false);
    }

    function maxProRataAvail(address purchaser) public view returns (uint256) {
        if (
            balanceOf(purchaser) == 0 ||
            holderFundingExpiry == 0 ||
            AelinDeal(aelinDealStorageProxy).proRataRedemptionStart() == 0 ||
            block.timestamp >=
            AelinDeal(aelinDealStorageProxy).proRataRedemptionExpiry()
        ) {
            return 0;
        }
        return
            (proRataConversion *
                (balanceOf(purchaser) + amountAccepted[purchaser])) /
            1e18 -
            amountAccepted[purchaser];
    }

    function maxOpenAvail(address purchaser) internal view returns (uint256) {
        return
            balanceOf(purchaser) + totalAmountAccepted <=
                purchaseTokenTotalForDeal
                ? balanceOf(purchaser)
                : purchaseTokenTotalForDeal - totalAmountAccepted;
    }

    function _acceptDealTokens(
        address recipient,
        uint256 poolTokenAmount,
        bool useMax
    ) internal dealFunded lock {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (
            block.timestamp >= aelinDeal.proRataRedemptionStart() &&
            block.timestamp < aelinDeal.proRataRedemptionExpiry()
        ) {
            _acceptDealTokensProRata(recipient, poolTokenAmount, useMax);
        } else if (
            aelinDeal.openRedemptionStart() > 0 &&
            block.timestamp < aelinDeal.openRedemptionExpiry()
        ) {
            _acceptDealTokensOpen(recipient, poolTokenAmount, useMax);
        } else {
            revert("outside of redeem window");
        }
    }

    function _acceptDealTokensProRata(
        address recipient,
        uint256 poolTokenAmount,
        bool useMax
    ) internal {
        uint256 maxProRata = maxProRataAvail(recipient);
        if (!useMax) {
            require(poolTokenAmount <= maxProRata, "accepting more than share");
        }
        uint256 acceptAmount = useMax ? maxProRata : poolTokenAmount;
        amountAccepted[recipient] += acceptAmount;
        totalAmountAccepted += acceptAmount;
        acceptDealLogic(recipient, acceptAmount);
        if (proRataConversion != 1e18 && maxProRataAvail(recipient) == 0) {
            openPeriodEligible[recipient] = true;
        }
    }

    function _acceptDealTokensOpen(
        address recipient,
        uint256 poolTokenAmount,
        bool useMax
    ) internal {
        require(
            openPeriodEligible[recipient],
            "ineligible: didn't max pro rata"
        );
        uint256 maxOpen = maxOpenAvail(recipient);
        uint256 acceptAmount = useMax ? maxOpen : poolTokenAmount;
        if (!useMax) {
            require(acceptAmount <= maxOpen, "accepting more than share");
        }
        acceptDealLogic(recipient, acceptAmount);
    }

    function acceptDealLogic(address recipient, uint256 poolTokenAmount)
        internal
    {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        _burn(recipient, poolTokenAmount);
        uint256 poolTokenDealFormatted = convertPoolToDeal(
            poolTokenAmount,
            purchaseTokenDecimals
        );
        uint256 aelinFeeAmt = (poolTokenDealFormatted * AELIN_FEE) / BASE;
        uint256 sponsorFeeAmt = (poolTokenDealFormatted * sponsorFee) / BASE;

        aelinDeal.mint(sponsor, sponsorFeeAmt);
        aelinDeal.mint(aelinRewardsAddress, aelinFeeAmt);
        aelinDeal.mint(
            recipient,
            poolTokenDealFormatted - (sponsorFeeAmt + aelinFeeAmt)
        );
        IERC20(purchaseToken).safeTransfer(holder, poolTokenAmount);
        emit AcceptDeal(
            recipient,
            aelinDealStorageProxy,
            poolTokenAmount,
            sponsorFeeAmt,
            aelinFeeAmt
        );
    }

    /**
     * @dev allows anyone to become a purchaser by sending purchase tokens
     * in exchange for pool tokens
     *
     * Requirements:
     * - the deal is in the purchase expiry window
     * - the cap has not been exceeded
     */
    function purchasePoolTokens(uint256 _purchaseTokenAmount) external lock {
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        uint256 currentBalance = IERC20(purchaseToken).balanceOf(address(this));
        IERC20(purchaseToken).safeTransferFrom(
            msg.sender,
            address(this),
            _purchaseTokenAmount
        );
        uint256 balanceAfterTransfer = IERC20(purchaseToken).balanceOf(
            address(this)
        );
        uint256 purchaseTokenAmount = balanceAfterTransfer - currentBalance;
        if (purchaseTokenCap > 0) {
            uint256 totalPoolAfter = totalSupply() + purchaseTokenAmount;
            require(
                totalPoolAfter <= purchaseTokenCap,
                "cap has been exceeded"
            );
            if (totalPoolAfter == purchaseTokenCap) {
                purchaseExpiry = block.timestamp;
            }
        }

        _mint(msg.sender, purchaseTokenAmount);
        emit PurchasePoolToken(msg.sender, purchaseTokenAmount);
    }

    /**
     * @dev the withdraw and partial withdraw methods allow a purchaser to take their
     * purchase tokens back in exchange for pool tokens if they do not accept a deal
     *
     * Requirements:
     * - the pool has expired either due to the creation of a deal or the end of the duration
     */
    function withdrawMaxFromPool() external {
        _withdraw(balanceOf(msg.sender));
    }

    function withdrawFromPool(uint256 purchaseTokenAmount) external {
        _withdraw(purchaseTokenAmount);
    }

    function _withdraw(uint256 purchaseTokenAmount) internal {
        require(block.timestamp >= poolExpiry, "not yet withdraw period");
        _burn(msg.sender, purchaseTokenAmount);
        IERC20(purchaseToken).safeTransfer(msg.sender, purchaseTokenAmount);
        emit WithdrawFromPool(msg.sender, purchaseTokenAmount);
    }

    /**
     * @dev view to see how much of the deal a purchaser can accept
     */
    function maxDealAccept(address purchaser) external view returns (uint256) {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (
            holderFundingExpiry == 0 ||
            aelinDeal.proRataRedemptionStart() == 0 ||
            (block.timestamp >= aelinDeal.proRataRedemptionExpiry() &&
                aelinDeal.openRedemptionStart() == 0) ||
            (block.timestamp >= aelinDeal.openRedemptionExpiry() &&
                aelinDeal.openRedemptionStart() != 0)
        ) {
            return 0;
        } else if (block.timestamp < aelinDeal.proRataRedemptionExpiry()) {
            return maxProRataAvail(purchaser);
        } else if (!openPeriodEligible[purchaser]) {
            return 0;
        } else {
            return maxOpenAvail(purchaser);
        }
    }

    /**
     * @dev pool tokens may not be transferred once the deal redemption window starts.
     * However, they may be withdrawn for purchase tokens which can then be transferred
     */
    modifier transferWindow() {
        require(
            AelinDeal(aelinDealStorageProxy).proRataRedemptionStart() == 0,
            "no transfers after redeem starts"
        );
        _;
    }

    function transfer(address dst, uint256 amount)
        public
        virtual
        override
        transferWindow
        returns (bool)
    {
        return super.transfer(dst, amount);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) public virtual override transferWindow returns (bool) {
        return super.transferFrom(src, dst, amount);
    }

    /**
     * @dev convert pool with varying decimals to deal tokens of 18 decimals
     * NOTE that a purchase token must not be greater than 18 decimals
     */
    function convertPoolToDeal(
        uint256 poolTokenAmount,
        uint256 poolTokenDecimals
    ) internal pure returns (uint256) {
        return poolTokenAmount * 10**(18 - poolTokenDecimals);
    }

    event SetSponsor(address indexed sponsor);
    event PurchasePoolToken(
        address indexed purchaser,
        uint256 purchaseTokenAmount
    );
    event WithdrawFromPool(
        address indexed purchaser,
        uint256 purchaseTokenAmount
    );
    event AcceptDeal(
        address indexed purchaser,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee
    );
    event CreateDeal(
        string name,
        string symbol,
        address indexed sponsor,
        address indexed dealContract
    );
    event DealDetails(
        address indexed dealContract,
        address indexed underlyingDealToken,
        uint256 purchaseTokenTotalForDeal,
        uint256 underlyingDealTokenTotal,
        uint256 vestingPeriod,
        uint256 vestingCliff,
        uint256 proRataRedemptionPeriod,
        uint256 openRedemptionPeriod,
        address indexed holder,
        uint256 holderFundingExpiry
    );
}
