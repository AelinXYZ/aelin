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

    uint public PURCHASE_EXPIRY;
    uint public POOL_EXPIRY;

    bool public CALLED_INITIALIZE = false;
    bool public DEAL_CREATED = false;

    address public AELIN_DEAL_STORAGE_PROXY;
    address public HOLDER;

    string private stored_name;
    string private stored_symbol;

    // @TODO update with correct addresses
    address constant AELIN_REWARDS = 0x0000000000000000000000000000000000000000;
    // NOTE this is created with create2
    address constant AELIN_DEAL_ADDRESS = 0xbcA4E7065BAE69Bb30A34D21Fb99464c81b600Ab;

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
        stored_name = _name;
        stored_symbol = _symbol;
        _setNameAndSymbol(
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol))
        );
        PURCHASE_TOKEN_CAP = _purchase_token_cap;
        PURCHASE_TOKEN = _purchase_token;
        PURCHASE_TOKEN_DECIMALS = IERC20(_purchase_token).decimals();
        require(365 days >= _duration, "max 1 year duration");
        POOL_EXPIRY = block.timestamp + _duration;
        require(30 minutes <= _purchase_expiry, "min 30 minutes purchase expiry");
        PURCHASE_EXPIRY = block.timestamp + _purchase_expiry;
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

        POOL_EXPIRY = block.timestamp;
        HOLDER = _holder;
        DEAL_CREATED = true;

        uint _pool_token_max_purchase_amount = convertUnderlyingToAelinAmount(
            _deal_purchase_token_total,
            PURCHASE_TOKEN_DECIMALS
        );

        PRO_RATA_CONVERSION = _pool_token_max_purchase_amount * 1e18 / totalSupply;
        uint _underlying_per_purchase_exchange_rate = _underlying_deal_token_total * 10**PURCHASE_TOKEN_DECIMALS / _deal_purchase_token_total; 

        AelinDeal AELIN_DEAL = AelinDeal(_cloneAsMinimalProxy(AELIN_DEAL_ADDRESS, "Could not create new deal"));
        AELIN_DEAL.initialize(
            stored_name,
            stored_symbol,
            _underlying_deal_token,
            _underlying_per_purchase_exchange_rate,
            _underlying_deal_token_total,
            _vesting_period,
            _vesting_cliff,
            _redemption_period,
            _holder,
            _pool_token_max_purchase_amount
        );
        AELIN_DEAL_STORAGE_PROXY = address(AELIN_DEAL);

        emit CreateDeal(
            string(abi.encodePacked("aeDeal-", stored_name)),
            string(abi.encodePacked("aeD-", stored_symbol)),
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

        return AELIN_DEAL_STORAGE_PROXY;
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
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        require(block.timestamp >= AELIN_DEAL.REDEMPTION_START() && block.timestamp < AELIN_DEAL.REDEMPTION_EXPIRY(), "outside of redeem window");
        require(pool_token_amount <= proRataBalance(msg.sender), "accepting more than deal share");
        _burn(msg.sender, pool_token_amount);

        uint aelin_fee = pool_token_amount * AELIN_FEE / BASE;
        uint sponsor_fee = pool_token_amount * SPONSOR_FEE / BASE;
        AELIN_DEAL.mint(SPONSOR, sponsor_fee);
        AELIN_DEAL.mint(AELIN_REWARDS, aelin_fee);
        AELIN_DEAL.mint(recipient, pool_token_amount - (sponsor_fee + aelin_fee));
        uint underlyingToHolderAmt = convertAelinToUnderlyingAmount(pool_token_amount, PURCHASE_TOKEN_DECIMALS);
        _safeTransfer(PURCHASE_TOKEN, HOLDER, underlyingToHolderAmt);
        emit AcceptDeal(recipient, address(this), AELIN_DEAL_STORAGE_PROXY, pool_token_amount, underlyingToHolderAmt);
    }

    function purchasePoolTokens(uint purchase_token_amount) external {
        _purchasePoolTokens(msg.sender, purchase_token_amount);
    }

    function purchasePoolTokensAndAllocate(address recipient, uint purchase_token_amount) external {
        _purchasePoolTokens(recipient, purchase_token_amount);
    }

    function _purchasePoolTokens(address recipient, uint purchase_token_amount) internal {
        require(DEAL_CREATED == false && block.timestamp < PURCHASE_EXPIRY, "not in purchase window");
        uint contract_purchase_balance = IERC20(PURCHASE_TOKEN).balanceOf(address(this));
        require(PURCHASE_TOKEN_CAP == 0 || contract_purchase_balance < PURCHASE_TOKEN_CAP, "the cap has been reached");

        if (PURCHASE_TOKEN_CAP > 0) {
            purchase_token_amount = (purchase_token_amount + contract_purchase_balance) <= PURCHASE_TOKEN_CAP ? purchase_token_amount : PURCHASE_TOKEN_CAP - contract_purchase_balance;
        }
        uint pool_token_amount = convertUnderlyingToAelinAmount(purchase_token_amount, PURCHASE_TOKEN_DECIMALS);
        _safeTransferFrom(PURCHASE_TOKEN, msg.sender, address(this), purchase_token_amount);
        _mint(recipient, pool_token_amount);
        emit PurchasePoolToken(recipient, msg.sender, address(this), purchase_token_amount, pool_token_amount);
    }

    function withdrawMaxFromPool() external {
        _withdraw(balanceOf[msg.sender]);
    }

    function withdrawFromPool(uint pool_token_amount) external {
        _withdraw(pool_token_amount);
    }

    function _withdraw(uint pool_token_amount) internal {
        require(block.timestamp > POOL_EXPIRY, "not yet withdraw period");
        _burn(msg.sender, pool_token_amount);
        uint purchase_withdraw_amount = convertAelinToUnderlyingAmount(pool_token_amount, PURCHASE_TOKEN_DECIMALS);
        _safeTransfer(PURCHASE_TOKEN, msg.sender, purchase_withdraw_amount);
        emit WithdrawFromPool(msg.sender, address(this), purchase_withdraw_amount, pool_token_amount);
    }

    function proRataBalance(address purchaser) public view returns (uint) {
        return PRO_RATA_CONVERSION * balanceOf[purchaser] / 1e18;
    }

    function maxPurchase() external view returns (uint) {
        if (DEAL_CREATED == true || block.timestamp >= PURCHASE_EXPIRY) {
            return 0;
        }
        if (PURCHASE_TOKEN_CAP == 0) {
            return type(uint).max;
        } else {
            return PURCHASE_TOKEN_CAP - IERC20(PURCHASE_TOKEN).balanceOf(address(this));
        }
    }

    event SetSponsor(address sponsor);
    event PurchasePoolToken(address recipient, address purchaser, address poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event WithdrawFromPool(address purchaser, address poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event AcceptDeal(address purchaser, address poolAddress, address dealAddress, uint poolTokenAmount, uint underlyingToHolderAmt);
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
