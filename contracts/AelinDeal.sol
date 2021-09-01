// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinPool.sol";

contract AelinDeal is AelinERC20 {
    address public HOLDER;
    address public UNDERLYING_DEAL_TOKEN;
    uint public UNDERLYING_DEAL_TOKEN_DECIMALS;
    uint public UNDERLYING_DEAL_TOKENS_TOTAL;
    uint public TOTAL_UNDERLYING_CLAIMED;

    uint public UNDERLYING_PER_POOL_EXCHANGE_RATE;
    uint public UNDERLYING_PER_PURCHASE_EXCHANGE_RATE;

    address public AELIN_POOL_ADDRESS;
    uint public VESTING_CLIFF;
    uint public VESTING_PERIOD;
    uint public VESTING_EXPIRY;

    uint public REDEMPTION_PERIOD;
    uint public REDEMPTION_START;
    uint public REDEMPTION_EXPIRY;
    
    bool public CALLED_INITIALIZE = false;
    bool public DEPOSIT_COMPLETE = false;

    constructor () {}
    
    function initialize (
        string memory _name, 
        string memory _symbol, 
        address _underlying_deal_token,
        uint _underlying_per_purchase_exchange_rate,
        uint _underlying_deal_token_total,
        uint _vesting_period, 
        uint _vesting_cliff,
        uint _redemption_period,
        address _holder,
        uint _pool_token_max_purchase_amount
    ) external initOnce {
        _setNameAndSymbol(
            string(abi.encodePacked("aeDeal-", _name)),
            string(abi.encodePacked("aeD-", _symbol))
        );

        HOLDER = _holder;
        UNDERLYING_DEAL_TOKEN = _underlying_deal_token;
        UNDERLYING_DEAL_TOKEN_DECIMALS = IERC20(_underlying_deal_token).decimals();
        UNDERLYING_DEAL_TOKENS_TOTAL = _underlying_deal_token_total;
        
        AELIN_POOL_ADDRESS = msg.sender;
        VESTING_CLIFF = block.timestamp + _redemption_period + _vesting_cliff;
        VESTING_PERIOD = _vesting_period;
        VESTING_EXPIRY = VESTING_CLIFF + _vesting_period;
        REDEMPTION_PERIOD = _redemption_period;

        CALLED_INITIALIZE = true;
        DEPOSIT_COMPLETE = false;

        // calculate the amount of underlying deal tokens you get per wrapped pool token accepted
        // NOTE 1 wrapped pool token = 1 wrapped deal token
        UNDERLYING_PER_POOL_EXCHANGE_RATE = _underlying_deal_token_total * 1e18 / _pool_token_max_purchase_amount;
        UNDERLYING_PER_PURCHASE_EXCHANGE_RATE = _underlying_per_purchase_exchange_rate;
    }

    modifier initOnce () {
        require(CALLED_INITIALIZE == false, "can only initialize once");
        _;
    }

    modifier finalizeDepositOnce () {
        require(DEPOSIT_COMPLETE == false, "deposit already complete");
        _;
    }

    // NOTE if the deposit was completed with a transfer instead of this method, 
    // the deposit can be finalized by calling this method with amount 0;
    function depositUnderlying(uint _underlying_deal_token_amount) external finalizeDepositOnce returns (bool) {
        if (IERC20(UNDERLYING_DEAL_TOKEN).balanceOf(address(this)) + _underlying_deal_token_amount >= UNDERLYING_DEAL_TOKENS_TOTAL) {
            DEPOSIT_COMPLETE = true;
        }
        if (_underlying_deal_token_amount > 0) {
            _safeTransferFrom(UNDERLYING_DEAL_TOKEN, msg.sender, address(this), _underlying_deal_token_amount);
            emit DepositDealTokens(UNDERLYING_DEAL_TOKEN, msg.sender, address(this), _underlying_deal_token_amount);
        }
        if (DEPOSIT_COMPLETE == true) {
            REDEMPTION_START = block.timestamp;
            REDEMPTION_EXPIRY = block.timestamp + REDEMPTION_PERIOD;

            emit DealFullyFunded(AELIN_POOL_ADDRESS, address(this), REDEMPTION_START, REDEMPTION_EXPIRY);
            return true;
        }
        return false;
    }
    
    // @NOTE the holder can withdraw any amount accidentally deposited over the amount needed to fulfill the deal
    function withdraw() external onlyHolder {
        uint withdraw_amount = IERC20(UNDERLYING_DEAL_TOKEN).balanceOf(address(this)) - UNDERLYING_DEAL_TOKENS_TOTAL - TOTAL_UNDERLYING_CLAIMED;
        _safeTransfer(UNDERLYING_DEAL_TOKEN, HOLDER, withdraw_amount);
        emit WithdrawUnderlyingDealTokens(UNDERLYING_DEAL_TOKEN, HOLDER, address(this), withdraw_amount);
    }

    function withdrawExpiry() external onlyHolder {
        require(REDEMPTION_EXPIRY > 0, "redemption period not started");
        require(block.timestamp > REDEMPTION_EXPIRY, "redeem window still active");
        uint withdraw_amount = IERC20(UNDERLYING_DEAL_TOKEN).balanceOf(address(this)) - (UNDERLYING_PER_POOL_EXCHANGE_RATE * totalSupply / 1e18);
        _safeTransfer(UNDERLYING_DEAL_TOKEN, HOLDER, withdraw_amount);
        emit WithdrawUnderlyingDealTokens(UNDERLYING_DEAL_TOKEN, HOLDER, address(this), withdraw_amount);
    }
    
    modifier onlyHolder() {
        require(msg.sender == HOLDER, "only holder can access");
        _;
    }
    
    modifier onlyPool() {
        require(msg.sender == AELIN_POOL_ADDRESS, "only AelinPool can access");
        _;
    }
    
    mapping(address => uint) public lastClaim;
    
    function underlyingDealTokensClaimable(address purchaser) external view returns (uint) {
        uint max_time = block.timestamp > VESTING_EXPIRY ? VESTING_EXPIRY : block.timestamp;
        if (max_time > VESTING_CLIFF || (max_time == VESTING_CLIFF && VESTING_PERIOD == 0 && lastClaim[purchaser] == 0)) {
            uint last_claimed = lastClaim[purchaser];
            if (last_claimed == 0) {
                last_claimed = VESTING_CLIFF;
            }
            if (last_claimed >= max_time && VESTING_PERIOD != 0) {
                return 0;
            } else {
                uint time_elapsed = max_time - last_claimed;
                uint deal_tokens_claimable = VESTING_PERIOD == 0 ? balanceOf[purchaser] : balanceOf[purchaser] * time_elapsed / VESTING_PERIOD;
                return UNDERLYING_PER_POOL_EXCHANGE_RATE * deal_tokens_claimable / 1e18;
            }
        } else {
            return 0;
        }
    }
    
    function claim(address from) external {
        _claim(from, from);
    }
    
    function claimAndAllocate(address from, address recipient) external {
        require(from == msg.sender, "only claimant can allocate");
        _claim(from, recipient);
    }
    
    function _claim(address from, address recipient) internal returns (uint deal_tokens_claimed) {

        if (balanceOf[from] > 0) {
            uint max_time = block.timestamp > VESTING_EXPIRY ? VESTING_EXPIRY : block.timestamp;
            if (max_time > VESTING_CLIFF || (max_time == VESTING_CLIFF && VESTING_PERIOD == 0 && lastClaim[from] == 0)) {
                if (lastClaim[from] == 0) {
                    lastClaim[from] = VESTING_CLIFF;
                }
                uint time_elapsed = max_time - lastClaim[from];
                uint deal_tokens_claimed = VESTING_PERIOD == 0 ? balanceOf[from] : balanceOf[from] * time_elapsed / VESTING_PERIOD;
                uint underlying_deal_tokens_claimed = UNDERLYING_PER_POOL_EXCHANGE_RATE * deal_tokens_claimed / 1e18;

                if (deal_tokens_claimed > 0) {
                    _burn(from, deal_tokens_claimed);
                    _safeTransfer(UNDERLYING_DEAL_TOKEN, recipient, underlying_deal_tokens_claimed);
                    TOTAL_UNDERLYING_CLAIMED += underlying_deal_tokens_claimed;
                    emit ClaimedUnderlyingDealTokens(UNDERLYING_DEAL_TOKEN, from, recipient, underlying_deal_tokens_claimed);
                }
                lastClaim[from] = max_time;
            }
        }
    }
    
    function mint(address dst, uint dealTokenAmount) external onlyPool {
        _mint(dst, dealTokenAmount);
        emit MintDealTokens(address(this), dst, dealTokenAmount);
    }

    function transfer(address dst, uint dealTokenAmount) external override returns (bool) {
        _transferTokens(msg.sender, dst, dealTokenAmount);
        return true;
    }

    // from a to b with amount
    function transferFrom(address src, address dst, uint amount) external override returns (bool) {
        address spender = msg.sender;
        uint spenderAllowance = allowance[src][spender];

        if (spender != src && spenderAllowance != type(uint).max) {
            uint newAllowance = spenderAllowance - amount;
            // NOTE does the newAllowance have to be greater than 0 or else the transaction will fail? Do we need to add a check for that?
            allowance[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    // @NOTE when you transfer deal tokens you have to claim your balance to that point and 
    // also claim for the receiving address in order to make sure the calculations are always
    // accurate after the transfer. you also need to check the latest balance after the initial
    // claim to make sure that you don't send more than you have left after claiming.
    function _transferTokens(address src, address dst, uint amount) internal override {
        _claim(src, src);
        uint transfer_amount = balanceOf[src] > amount ? balanceOf[src] : amount;
        _claim(dst, dst);
        balanceOf[dst] += transfer_amount;
        
        emit Transfer(src, dst, transfer_amount);
    }

    event DealFullyFunded(address poolAddress, address dealAddress, uint redemptionStart, uint redemptionExpiry);
    event DepositDealTokens(address underlyingDealTokenAddress, address depositor, address dealContract, uint underlyingDealTokenAmount);
    event WithdrawUnderlyingDealTokens(address underlyingDealTokenAddress, address depositor, address dealContract, uint underlyingDealTokenAmount);
    event ClaimedUnderlyingDealTokens(address underlyingDealTokenAddress, address from, address recipient, uint underlyingDealTokensClaimed);
    event MintDealTokens(address dealContract, address recipient, uint dealTokenAmount);
}