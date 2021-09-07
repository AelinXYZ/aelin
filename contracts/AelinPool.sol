// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./MinimalProxyFactory.sol";

import "hardhat/console.sol";

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
    mapping(address => bool) public OPEN_PERIOD_ELIGIBLE;
    mapping(address => uint) public DEAL_AMT_ALLOCATED;

    string private stored_name;
    string private stored_symbol;


    // @TODO update with correct addresses
    address constant AELIN_REWARDS = 0x0000000000000000000000000000000000000000;
    // NOTE this is created with create2
    address constant AELIN_DEAL_ADDRESS = 0x9e641c7155d72Ee9EF1f383B74117647aeD3006A;

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

    modifier dealCreated() {
        require(DEAL_CREATED == true, "deal not yet created");
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
        uint _pro_rata_redemption_period,
        uint _open_redemption_period,
        address _holder
    ) external onlySponsor dealNotCreated returns (address) {
        require(30 minutes <= _pro_rata_redemption_period, "30 mins is min prorata period");
        uint _pool_token_max_purchase_amount = convertUnderlyingToAelinAmount(
            _deal_purchase_token_total,
            PURCHASE_TOKEN_DECIMALS
        );
        require(_pool_token_max_purchase_amount <= totalSupply, "not enough funds available");
        PRO_RATA_CONVERSION = _pool_token_max_purchase_amount * 1e18 / totalSupply;
        console.log("PRO_RATA_CONVERSION: %s", PRO_RATA_CONVERSION);
        if (PRO_RATA_CONVERSION == 1e18) {
            require(0 minutes == _open_redemption_period, "deal is 1:1, set open to 0");
        } else {
            require(30 minutes <= _open_redemption_period, "30 mins is min open period");
        }

        POOL_EXPIRY = block.timestamp;
        HOLDER = _holder;
        DEAL_CREATED = true;

        AelinDeal AELIN_DEAL = AelinDeal(_cloneAsMinimalProxy(AELIN_DEAL_ADDRESS, "Could not create new deal"));
        AELIN_DEAL.initialize(
            stored_name,
            stored_symbol,
            _underlying_deal_token,
            _underlying_deal_token_total,
            _vesting_period,
            _vesting_cliff,
            _pro_rata_redemption_period,
            _open_redemption_period,
            _holder,
            _pool_token_max_purchase_amount
        );
        AELIN_DEAL_STORAGE_PROXY = address(AELIN_DEAL);

        emit CreateDeal(
            string(abi.encodePacked("aeDeal-", stored_name)),
            string(abi.encodePacked("aeD-", stored_symbol)),
            SPONSOR,
            address(this),
            address(AELIN_DEAL)
        );

        emit DealDetails(
            address(AELIN_DEAL),
            _underlying_deal_token,
            _deal_purchase_token_total,
            _underlying_deal_token_total,
            _vesting_period,
            _vesting_cliff,
            _pro_rata_redemption_period,
            _open_redemption_period,
            _holder
        );

        return AELIN_DEAL_STORAGE_PROXY;
    }

    function acceptMaxDealTokens() external {
        _acceptDealTokens(msg.sender, 0, true, false);
    }

    function acceptMaxDealTokensAndAllocate(address recipient) external {
        _acceptDealTokens(recipient, 0, true, true);
    }

    function acceptDealTokens(uint pool_token_amount) external {
        _acceptDealTokens(msg.sender, pool_token_amount, false, false);
    }

    function acceptDealTokensAndAllocate(address recipient, uint pool_token_amount) external {
        _acceptDealTokens(recipient, pool_token_amount, false, true);
    }

    function maxProRataAvail(address purchaser) public view returns (uint) {
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        if (balanceOf[purchaser] == 0 || DEAL_CREATED == false || block.timestamp >= AELIN_DEAL.PRO_RATA_REDEMPTION_EXPIRY()) {
            return 0;
        }
        console.log("maxProRataAvail");
        console.log("PRO_RATA_CONVERSION", PRO_RATA_CONVERSION);
        console.log("purchaser", purchaser);
        console.log("balanceOf[purchaser]", balanceOf[purchaser]);
        console.log("DEAL_AMT_ALLOCATED[purchaser]", DEAL_AMT_ALLOCATED[purchaser]);
        console.log("AELIN_DEAL.balanceOf(purchaser)", AELIN_DEAL.balanceOf(purchaser));
        console.log("(PRO_RATA_CONVERSION * balanceOf[purchaser] / 1e18)", (PRO_RATA_CONVERSION * balanceOf[purchaser] / 1e18));
        console.log('end maxProRataAvail');
        uint higher_base = AELIN_DEAL.balanceOf(purchaser) * BASE / (BASE - AELIN_FEE - SPONSOR_FEE);
        console.log("higher_base: %s", higher_base);
        uint amount_accepted = AELIN_DEAL.balanceOf(purchaser) * BASE / (BASE - AELIN_FEE - SPONSOR_FEE) - DEAL_AMT_ALLOCATED[purchaser];
        console.log("(PRO_RATA_CONVERSION * amount_accepted / 1e18)", (PRO_RATA_CONVERSION * amount_accepted / 1e18));
        console.log("summation: %s", ((PRO_RATA_CONVERSION * (balanceOf[purchaser] + amount_accepted) / 1e18)));
        console.log("amount_accepted: %s", amount_accepted);

        return PRO_RATA_CONVERSION * (balanceOf[purchaser] + amount_accepted) / 1e18 - amount_accepted;
    }

    function maxOpenAvail(address purchaser) internal view returns (uint) {
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        return balanceOf[purchaser] + AELIN_DEAL.totalSupply() <= AELIN_DEAL.MAX_TOTAL_SUPPLY() ?
            balanceOf[purchaser] :
            AELIN_DEAL.MAX_TOTAL_SUPPLY() - AELIN_DEAL.totalSupply();
    }

    function _acceptDealTokens(address recipient, uint pool_token_amount, bool use_max, bool is_allocated) internal dealCreated {
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        if (block.timestamp >= AELIN_DEAL.PRO_RATA_REDEMPTION_START() && block.timestamp < AELIN_DEAL.PRO_RATA_REDEMPTION_EXPIRY()) {
            _acceptDealTokensProRata(recipient, pool_token_amount, use_max, is_allocated);
        } else if (AELIN_DEAL.OPEN_REDEMPTION_START() > 0 && block.timestamp < AELIN_DEAL.OPEN_REDEMPTION_EXPIRY()) {
            _acceptDealTokensOpen(recipient, pool_token_amount, use_max, is_allocated);
        } else {
            revert("outside of redeem window");
        }
    }

    function _acceptDealTokensProRata(address recipient, uint pool_token_amount, bool use_max, bool is_allocated) internal {
        uint max_pro_rata_avail = maxProRataAvail(msg.sender);
        console.log('initial max pro rata avail: %s', max_pro_rata_avail);
        if (!use_max) {
            require(pool_token_amount <= max_pro_rata_avail, "accepting more than share");
        }
        uint accept_amount = use_max ? max_pro_rata_avail : pool_token_amount;
        acceptDealLogic(recipient, accept_amount, is_allocated);
        uint end_max_avail = maxProRataAvail(msg.sender);
        console.log('ending max pro rata avail: %s', end_max_avail);
        if (PRO_RATA_CONVERSION != 1e18 && end_max_avail == 0) {
            console.log('eligible');
            OPEN_PERIOD_ELIGIBLE[msg.sender] = true;
        }
    }

    function _acceptDealTokensOpen(address recipient, uint pool_token_amount, bool use_max, bool is_allocated) internal {
        require(OPEN_PERIOD_ELIGIBLE[msg.sender], "ineligible: didn't max pro rata");
        uint max_open_avail = maxOpenAvail(msg.sender);
        uint accept_amount = use_max ? max_open_avail : pool_token_amount;
        if (!use_max) {
            require(accept_amount <= max_open_avail, "accepting more than share");
        }
        acceptDealLogic(recipient, accept_amount, is_allocated);
    }

    function acceptDealLogic(address recipient, uint pool_token_amount, bool is_allocated) internal {
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        if (is_allocated) {
            console.log('allocating: %s to recipient: %s', pool_token_amount, recipient);
            DEAL_AMT_ALLOCATED[recipient] += pool_token_amount;
        }
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
        console.log("first purchase_token_amount: %s", purchase_token_amount);
        if (PURCHASE_TOKEN_CAP > 0) {
            purchase_token_amount = (purchase_token_amount + contract_purchase_balance) <= PURCHASE_TOKEN_CAP ? purchase_token_amount : PURCHASE_TOKEN_CAP - contract_purchase_balance;
            console.log("optional purchase_token_amount: %s", purchase_token_amount);
        }
        console.log("last purchase_token_amount: %s", purchase_token_amount);
        console.log("PURCHASE_TOKEN_DECIMALS: %s", PURCHASE_TOKEN_DECIMALS);
        uint pool_token_amount = convertUnderlyingToAelinAmount(purchase_token_amount, PURCHASE_TOKEN_DECIMALS);
        console.log("pool_token_amount: %s", pool_token_amount);
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

    function maxDealAccept(address purchaser) external view returns (uint) {
        AelinDeal AELIN_DEAL = AelinDeal(AELIN_DEAL_STORAGE_PROXY);
        if (
            DEAL_CREATED == false ||
            (block.timestamp > AELIN_DEAL.OPEN_REDEMPTION_EXPIRY() && AELIN_DEAL.OPEN_REDEMPTION_START() == 0) ||
            block.timestamp > AELIN_DEAL.OPEN_REDEMPTION_EXPIRY()
        ) {
            return 0;
        } else if (block.timestamp < AELIN_DEAL.PRO_RATA_REDEMPTION_EXPIRY()) {
            return maxProRataAvail(purchaser);
        } else if (!OPEN_PERIOD_ELIGIBLE[purchaser]) {
            return 0;
        } else {
            return maxOpenAvail(purchaser);
        }
    }

    function maxPoolPurchase() external view returns (uint) {
        if (DEAL_CREATED == true || block.timestamp >= PURCHASE_EXPIRY) {
            return 0;
        }
        if (PURCHASE_TOKEN_CAP == 0) {
            return type(uint).max;
        } else {
            return PURCHASE_TOKEN_CAP - IERC20(PURCHASE_TOKEN).balanceOf(address(this));
        }
    }

    event SetSponsor(address indexed sponsor);
    event PurchasePoolToken(address indexed recipient, address indexed purchaser, address indexed poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event WithdrawFromPool(address indexed purchaser, address indexed poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event AcceptDeal(address indexed purchaser, address indexed poolAddress, address indexed dealAddress, uint poolTokenAmount, uint underlyingToHolderAmt);
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
        uint dealPurchaseTokenTotal,
        uint underlyingDealTokenTotal,
        uint vestingPeriod,
        uint vestingCliff,
        uint proRataRedemptionPeriod,
        uint openRedemptionPeriod,
        address indexed holder
    );
}
