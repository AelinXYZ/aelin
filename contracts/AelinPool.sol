// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./MinimalProxyFactory.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory {
    address public PURCHASE_TOKEN;
    uint public PURCHASE_TOKEN_CAP;
    uint public PURCHASE_TOKEN_DECIMALS;
    uint public PRO_RATA_CONVERSION;

    uint public SPONSOR_FEE;
    address public SPONSOR;
    address public FUTURE_SPONSOR;

    uint constant BASE = 100000;
    uint constant MAX_SPONSOR_FEE = 98000;
    uint constant AELIN_FEE = 2000;

    uint public purchase_expiry;
    uint public pool_expiry;

    bool CALLED_INITIALIZE = false;
    bool DEAL_CREATED = false;

    AelinDeal public AELIN_DEAL;
    address public holder;

    // @TODO update with correct addresses
    address constant AELIN_DEAL_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant AELIN_REWARDS = 0x0000000000000000000000000000000000000000;

    constructor () {}

    function initialize (
        string memory _name,
        string memory _symbol,
        uint _purchase_token_cap,
        address _purchase_token,
        uint _duration,
        uint _sponsor_fee,
        address _sponsor,
        uint _purchase_expiry
    ) external initOnce {
        _setNameAndSymbol(
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol))
        );
        PURCHASE_TOKEN_CAP = _purchase_token_cap;
        PURCHASE_TOKEN = _purchase_token;
        PURCHASE_TOKEN_DECIMALS = IERC20(_purchase_token).decimals();
        require(365 days >= _duration, "max 1 year duration");
        pool_expiry = block.timestamp + _duration;
        require(30 minutes <= _purchase_expiry, "min 30 minutes purchase expiry");
        purchase_expiry = block.timestamp + _purchase_expiry;
        require(_sponsor_fee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");
        SPONSOR_FEE = _sponsor_fee;
        SPONSOR = _sponsor;

        CALLED_INITIALIZE = true;
        emit SetSponsor(_sponsor);
    }

    modifier dealNotCreated() {
        require(DEAL_CREATED == false, "deal has been created");
        _;
    }

    modifier initOnce() {
        require(CALLED_INITIALIZE == false, "can only initialize once");
        _;
    }
    
    modifier onlySponsor() {
        require(msg.sender == SPONSOR, "only sponsor can access");
        _;
    }
    
    function setSponsor(address _sponsor) external onlySponsor  {
        FUTURE_SPONSOR = _sponsor;
    }
    
    function acceptSponsor() external {
        require(msg.sender == FUTURE_SPONSOR, "only future sponsor can access");
        SPONSOR = FUTURE_SPONSOR;
        emit SetSponsor(FUTURE_SPONSOR);
    }

    function createDeal(
        address _underlying_deal_token,
        uint _deal_purchase_token_total,
        uint _underlying_deal_token_total,
        uint _vesting_period,
        uint _vesting_cliff,
        uint _redemption_period,
        address _holder
    ) external onlySponsor dealNotCreated returns (address) {
        require(30 minutes <= _redemption_period, "30 mins is min redeem period");
        require(IERC20(PURCHASE_TOKEN).balanceOf(address(this)) > 0, "no purchase tokens in the contract");
        require(_deal_purchase_token_total <= IERC20(PURCHASE_TOKEN).balanceOf(address(this)), "not enough funds avail");

        pool_expiry = block.timestamp;
        holder = _holder;
        DEAL_CREATED = true;

        uint _pool_token_max_purchase_amount = convertUnderlyingToAelinAmount(
            _deal_purchase_token_total,
            PURCHASE_TOKEN_DECIMALS
        );

        PRO_RATA_CONVERSION = _pool_token_max_purchase_amount * 1e18 / totalSupply;
        uint _underlying_per_purchase_exchange_rate = _underlying_deal_token_total * 10**PURCHASE_TOKEN_DECIMALS / _deal_purchase_token_total; 

        AelinDeal AELIN_DEAL = AelinDeal(_cloneAsMinimalProxy(AELIN_DEAL_ADDRESS, "Could not create new deal"));
        AELIN_DEAL.initialize(
            name,
            symbol,
            _underlying_deal_token,
            _underlying_per_purchase_exchange_rate,
            _underlying_deal_token_total,
            _vesting_period,
            _vesting_cliff,
            _redemption_period,
            _holder,
            _pool_token_max_purchase_amount
        );

        emit CreateDeal(
            name,
            symbol,
            address(AELIN_DEAL),
            _underlying_deal_token,
            _deal_purchase_token_total,
            _underlying_deal_token_total,
            _vesting_period,
            _vesting_cliff,
            _redemption_period,
            _holder,
            _pool_token_max_purchase_amount
        );

        return address(AELIN_DEAL);
    }

    function acceptMaxDealTokens() external {
        _acceptDealTokens(msg.sender, proRataBalance(msg.sender));
    }

    function acceptMaxDealTokensAndAllocate(address recipient) external {
        _acceptDealTokens(recipient, proRataBalance(msg.sender));
    }

    function acceptDealTokens(uint pool_token_amount) external {
        _acceptDealTokens(msg.sender, pool_token_amount);
    }

    function acceptDealTokensAndAllocate(address recipient, uint pool_token_amount) external {
        _acceptDealTokens(recipient, pool_token_amount);
    }

    function _acceptDealTokens(address recipient, uint pool_token_amount) internal {
        require(DEAL_CREATED == true, "deal not yet created");
        require(block.timestamp >= AELIN_DEAL.REDEMPTION_START() && block.timestamp < AELIN_DEAL.REDEMPTION_EXPIRY(), "outside of redeem window");
        require(pool_token_amount <= proRataBalance(msg.sender), "accepting more than deal share");
        _burn(msg.sender, pool_token_amount);

        uint aelin_fee = pool_token_amount * AELIN_FEE / BASE;
        uint sponsor_fee = pool_token_amount * SPONSOR_FEE / BASE;
        AELIN_DEAL.mint(SPONSOR, sponsor_fee);
        AELIN_DEAL.mint(AELIN_REWARDS, aelin_fee);
        AELIN_DEAL.mint(recipient, pool_token_amount - (sponsor_fee + aelin_fee));
        _safeTransfer(PURCHASE_TOKEN, holder, convertAelinToUnderlyingAmount(pool_token_amount, PURCHASE_TOKEN_DECIMALS));
        emit AcceptDeal(recipient, address(this), address(AELIN_DEAL), pool_token_amount);
    }

    function purchasePoolTokens(uint purchase_token_amount) external {
        _purchasePoolTokens(msg.sender, purchase_token_amount);
    }

    function purchasePoolTokensAndAllocate(address recipient, uint purchase_token_amount) external {
        _purchasePoolTokens(recipient, purchase_token_amount);
    }

    function _purchasePoolTokens(address recipient, uint purchase_token_amount) internal {
        require(DEAL_CREATED == false && block.timestamp < purchase_expiry, "not in purchase window");
        uint contract_purchase_balance = IERC20(PURCHASE_TOKEN).balanceOf(address(this));
        require(PURCHASE_TOKEN_CAP == 0 || contract_purchase_balance < PURCHASE_TOKEN_CAP, "the cap has been reached");

        if (PURCHASE_TOKEN_CAP > 0) {
            purchase_token_amount = (purchase_token_amount + contract_purchase_balance) <= PURCHASE_TOKEN_CAP ? purchase_token_amount : PURCHASE_TOKEN_CAP - contract_purchase_balance;
        }
        uint pool_token_amount = convertUnderlyingToAelinAmount(purchase_token_amount, PURCHASE_TOKEN_DECIMALS);
        _safeTransferFrom(PURCHASE_TOKEN, msg.sender, address(this), purchase_token_amount);
        _mint(recipient, pool_token_amount);
        emit PurchasePoolToken(recipient, address(this), purchase_token_amount, pool_token_amount);
    }

    function withdrawMaxFromPool() external {
        _withdraw(balanceOf[msg.sender]);
    }

    function withdrawFromPool(uint pool_token_amount) external {
        _withdraw(pool_token_amount);
    }

    function _withdraw(uint pool_token_amount) internal {
        require(block.timestamp > pool_expiry, "not yet withdraw period");
        _burn(msg.sender, pool_token_amount);
        uint purchase_withdraw_amount = convertAelinToUnderlyingAmount(pool_token_amount, PURCHASE_TOKEN_DECIMALS);
        _safeTransfer(PURCHASE_TOKEN, msg.sender, purchase_withdraw_amount);
        emit WithdrawFromPool(msg.sender, address(this), purchase_withdraw_amount, pool_token_amount);
    }

    function proRataBalance(address purchaser) internal view returns (uint) {
        return PRO_RATA_CONVERSION / 1e18 * balanceOf[purchaser];
    }

    function maxAcceptDealTokens(address pool_token_owner) external view returns (uint) {
        if (DEAL_CREATED == false || AELIN_DEAL.REDEMPTION_START() == 0 || block.timestamp > AELIN_DEAL.REDEMPTION_EXPIRY()) {
            return 0;
        }
        return proRataBalance(pool_token_owner);
    }

    function maxPurchase() external view returns (uint) {
        if (DEAL_CREATED == true || block.timestamp >= purchase_expiry) {
            return 0;
        }
        if (PURCHASE_TOKEN_CAP == 0) {
            return type(uint).max;
        } else {
            return PURCHASE_TOKEN_CAP - IERC20(PURCHASE_TOKEN).balanceOf(address(this));
        }
    }

    event SetSponsor(address sponsor);
    event PurchasePoolToken(address purchaser, address poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event WithdrawFromPool(address purchaser, address poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event AcceptDeal(address purchaser, address poolAddress, address dealAddress, uint poolTokenAmount);
    event CreateDeal(
        string name,
        string symbol,
        address dealContract,
        address underlyingDealToken,
        uint dealPurchaseTokenTotal,
        uint underlyingDealTokenTotal,
        uint vestingPeriod,
        uint vestingCliff,
        uint redemptionPeriod,
        address holder,
        uint poolTokenMaxPurchaseAmount
    );
}
