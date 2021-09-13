// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./MinimalProxyFactory.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory {
    address public purchaseToken;
    uint256 public purchaseTokenCap;
    uint256 public purchaseTokenDecimals;
    uint256 public proRataConversion;

    uint256 public sponsorFee;
    address public sponsor;
    address public futureSponsor;

    uint256 constant BASE = 100000;
    uint256 constant MAX_SPONSOR_FEE = 98000;
    uint256 constant AELIN_FEE = 2000;

    uint256 public purchaseExpiry;
    uint256 public poolExpiry;

    bool public calledInitialize = false;
    bool public dealCreated = false;

    address public aelinDealLogicAddress;
    address public aelinDealStorageProxy;
    address public holder;
    mapping(address => uint256) public amountAccepted;
    mapping(address => bool) public openPeriodEligible;

    string private storedName;
    string private storedSymbol;

    // @TODO update with correct addresses
    // HOW to manage the aelin rewards address???
    address constant AELIN_REWARDS = 0x5A0b54D5dc17e0AadC383d2db43B0a0D3E029c4c;

    constructor() {}

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _purchaseTokenCap,
        address _purchaseToken,
        uint256 _duration,
        uint256 _sponsorFee,
        address _sponsor,
        uint256 _purchaseExpiry,
        address _aelinDealLogicAddress
    ) external initOnce {
        storedName = _name;
        storedSymbol = _symbol;
        _setNameAndSymbol(
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol))
        );
        purchaseTokenCap = _purchaseTokenCap;
        purchaseToken = _purchaseToken;
        purchaseTokenDecimals = IERC20Decimals(_purchaseToken).decimals();
        require(365 days >= _duration, "max 1 year duration");
        poolExpiry = block.timestamp + _duration;
        require(
            30 minutes <= _purchaseExpiry && 30 days >= _purchaseExpiry,
            "outside purchase expiry window"
        );
        purchaseExpiry = block.timestamp + _purchaseExpiry;
        require(_sponsorFee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");
        sponsorFee = _sponsorFee;
        sponsor = _sponsor;
        aelinDealLogicAddress = _aelinDealLogicAddress;

        calledInitialize = true;
        emit SetSponsor(_sponsor);
    }

    modifier dealNotCreated() {
        require(dealCreated == false, "deal has been created");
        _;
    }

    modifier initOnce() {
        require(calledInitialize == false, "can only initialize once");
        _;
    }

    modifier onlySponsor() {
        require(msg.sender == sponsor, "only sponsor can access");
        _;
    }

    modifier dealAlreadyCreated() {
        require(dealCreated == true, "deal not yet created");
        _;
    }

    function setSponsor(address _sponsor) external onlySponsor {
        futureSponsor = _sponsor;
    }

    function acceptSponsor() external {
        require(msg.sender == futureSponsor, "only future sponsor can access");
        sponsor = futureSponsor;
        emit SetSponsor(futureSponsor);
    }

    function createDeal(
        address _underlyingDealToken,
        uint256 _purchaseTokenTotalForDeal,
        uint256 _underlyingDealTokenTotal,
        uint256 _vestingPeriod,
        uint256 _vestingCliff,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        address _holder
    ) external onlySponsor dealNotCreated returns (address) {
        require(
            block.timestamp >= purchaseExpiry,
            "pool still in purchase mode"
        );
        require(
            30 minutes <= _proRataRedemptionPeriod &&
                30 days >= _proRataRedemptionPeriod,
            "30 mins - 30 days for prorata"
        );
        uint256 poolTokenMaxPurchaseAmount = convertUnderlyingToAelinAmount(
            _purchaseTokenTotalForDeal,
            purchaseTokenDecimals
        );
        require(
            poolTokenMaxPurchaseAmount <= totalSupply(),
            "not enough funds available"
        );
        proRataConversion = (poolTokenMaxPurchaseAmount * 1e18) / totalSupply();
        if (proRataConversion == 1e18) {
            require(
                0 minutes == _openRedemptionPeriod,
                "deal is 1:1, set open to 0"
            );
        } else {
            require(
                30 minutes <= _openRedemptionPeriod,
                "30 mins is min open period"
            );
        }

        poolExpiry = block.timestamp;
        holder = _holder;
        dealCreated = true;

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
            poolTokenMaxPurchaseAmount
        );
        aelinDealStorageProxy = address(aelinDeal);

        emit CreateDeal(
            string(abi.encodePacked("aeDeal-", storedName)),
            string(abi.encodePacked("aeD-", storedSymbol)),
            sponsor,
            address(this),
            address(aelinDeal)
        );

        emit DealDetails(
            address(aelinDeal),
            _underlyingDealToken,
            _purchaseTokenTotalForDeal,
            _underlyingDealTokenTotal,
            _vestingPeriod,
            _vestingCliff,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _holder
        );

        return aelinDealStorageProxy;
    }

    function acceptMaxDealTokens() external {
        _acceptDealTokens(msg.sender, 0, true);
    }

    function acceptDealTokens(uint256 poolTokenAmount) external {
        _acceptDealTokens(msg.sender, poolTokenAmount, false);
    }

    function maxProRataAvail(address purchaser) public view returns (uint256) {
        if (
            balanceOf(purchaser) == 0 ||
            dealCreated == false ||
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
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        return
            balanceOf(purchaser) + aelinDeal.totalSupply() <=
                aelinDeal.maxTotalSupply()
                ? balanceOf(purchaser)
                : aelinDeal.maxTotalSupply() - aelinDeal.totalSupply();
    }

    function _acceptDealTokens(
        address recipient,
        uint256 poolTokenAmount,
        bool useMax
    ) internal dealAlreadyCreated {
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
        uint256 aelinFeeAmt = (poolTokenAmount * AELIN_FEE) / BASE;
        uint256 sponsorFeeAmt = (poolTokenAmount * sponsorFee) / BASE;
        aelinDeal.mint(sponsor, sponsorFeeAmt);
        aelinDeal.mint(AELIN_REWARDS, aelinFeeAmt);
        aelinDeal.mint(
            recipient,
            poolTokenAmount - (sponsorFeeAmt + aelinFeeAmt)
        );

        uint256 underlyingToHolderAmt = convertAelinToUnderlyingAmount(
            poolTokenAmount,
            purchaseTokenDecimals
        );
        _safeTransfer(purchaseToken, holder, underlyingToHolderAmt);
        emit AcceptDeal(
            recipient,
            address(this),
            aelinDealStorageProxy,
            poolTokenAmount,
            sponsorFeeAmt,
            aelinFeeAmt,
            underlyingToHolderAmt
        );
    }

    function purchasePoolTokens(uint256 _purchaseTokenAmount) external {
        _purchasePoolTokens(_purchaseTokenAmount, false);
    }

    function purchasePoolTokensUpToAmount(uint256 _purchaseTokenAmount)
        external
    {
        _purchasePoolTokens(_purchaseTokenAmount, true);
    }

    function _purchasePoolTokens(
        uint256 _purchaseTokenAmount,
        bool _usePartialFill
    ) internal {
        require(
            dealCreated == false && block.timestamp < purchaseExpiry,
            "not in purchase window"
        );
        uint256 purchaseAmount = _purchaseTokenAmount;
        uint256 poolTokenAmount = convertUnderlyingToAelinAmount(
            purchaseAmount,
            purchaseTokenDecimals
        );
        uint256 poolTokenCap = convertUnderlyingToAelinAmount(
            purchaseTokenCap,
            purchaseTokenDecimals
        );

        if (
            _usePartialFill && (totalSupply() + poolTokenAmount) > poolTokenCap
        ) {
            poolTokenAmount = poolTokenCap - totalSupply();
            purchaseAmount = convertAelinToUnderlyingAmount(
                poolTokenAmount,
                purchaseTokenDecimals
            );
        }

        uint256 totalPoolAfter = totalSupply() + poolTokenAmount;
        require(
            purchaseTokenCap == 0 ||
                _usePartialFill ||
                (!_usePartialFill && totalPoolAfter <= poolTokenCap),
            "cap has been exceeded"
        );

        if (totalPoolAfter == poolTokenCap) {
            purchaseExpiry = block.timestamp;
        }
        _safeTransferFrom(
            purchaseToken,
            msg.sender,
            address(this),
            purchaseAmount
        );
        _mint(msg.sender, poolTokenAmount);
        emit PurchasePoolToken(
            msg.sender,
            address(this),
            purchaseAmount,
            poolTokenAmount
        );
    }

    function withdrawMaxFromPool() external {
        _withdraw(balanceOf(msg.sender));
    }

    function withdrawFromPool(uint256 poolTokenAmount) external {
        _withdraw(poolTokenAmount);
    }

    function _withdraw(uint256 poolTokenAmount) internal {
        require(block.timestamp > poolExpiry, "not yet withdraw period");
        _burn(msg.sender, poolTokenAmount);
        uint256 purchaseWithdrawAmount = convertAelinToUnderlyingAmount(
            poolTokenAmount,
            purchaseTokenDecimals
        );
        _safeTransfer(purchaseToken, msg.sender, purchaseWithdrawAmount);
        emit WithdrawFromPool(
            msg.sender,
            address(this),
            purchaseWithdrawAmount,
            poolTokenAmount
        );
    }

    function maxDealAccept(address purchaser) external view returns (uint256) {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (
            dealCreated == false ||
            (block.timestamp >= aelinDeal.proRataRedemptionExpiry() &&
                aelinDeal.openRedemptionStart() == 0) ||
            (block.timestamp > aelinDeal.openRedemptionExpiry() &&
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

    function maxPoolPurchase() external view returns (uint256) {
        if (dealCreated == true || block.timestamp >= purchaseExpiry) {
            return 0;
        }
        if (purchaseTokenCap == 0) {
            return type(uint256).max;
        } else {
            uint256 poolTokenCap = convertUnderlyingToAelinAmount(
                purchaseTokenCap,
                purchaseTokenDecimals
            );
            uint256 remainingAmount = poolTokenCap - totalSupply();
            return
                convertAelinToUnderlyingAmount(
                    remainingAmount,
                    purchaseTokenDecimals
                );
        }
    }

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
        _transfer(msg.sender, dst, amount);
        return true;
    }

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) public virtual override transferWindow returns (bool) {
        _transfer(src, dst, amount);

        uint256 currentAllowance = _allowances[src][msg.sender];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(src, _msgSender(), currentAllowance - amount);
        }
        return true;
    }

    event SetSponsor(address indexed sponsor);
    event PurchasePoolToken(
        address indexed purchaser,
        address indexed poolAddress,
        uint256 purchaseTokenAmount,
        uint256 poolTokenAmount
    );
    event WithdrawFromPool(
        address indexed purchaser,
        address indexed poolAddress,
        uint256 purchaseTokenAmount,
        uint256 poolTokenAmount
    );
    event AcceptDeal(
        address indexed purchaser,
        address indexed poolAddress,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee,
        uint256 underlyingToHolderAmt
    );
    event CreateDeal(
        string name,
        string symbol,
        address indexed sponsor,
        address indexed poolAddress,
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
        address indexed holder
    );
}
