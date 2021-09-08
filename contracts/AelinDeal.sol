// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinPool.sol";

contract AelinDeal is AelinERC20 {
    uint public maxTotalSupply;

    address public underlyingDealToken;
    uint public underlyingDealTokenDecimals;
    uint public underlyingDealTokenTotal;
    uint public totalUnderlyingClaimed;
    address public holder;

    uint public underlyingPerPoolExchangeRate;

    address public aelinPool;
    uint public vestingCliff;
    uint public vestingPeriod;
    uint public vestingExpiry;

    uint public proRataRedemptionPeriod;
    uint public proRataRedemptionStart;
    uint public proRataRedemptionExpiry;

    uint public openRedemptionPeriod;
    uint public openRedemptionStart;
    uint public openRedemptionExpiry;
    
    bool public calledInitialize;
    bool public depositComplete;

    constructor () {}
    
    function initialize (
        string memory _name, 
        string memory _symbol, 
        address _underlyingDealToken,
        uint _underlyingDealTokenTotal,
        uint _vestingPeriod, 
        uint _vestingCliff,
        uint _proRataRedemptionPeriod,
        uint _openRedemptionPeriod,
        address _holder,
        uint _poolTokenMaxPurchaseAmount
    ) external initOnce {
        _setNameAndSymbol(
            string(abi.encodePacked("aeDeal-", _name)),
            string(abi.encodePacked("aeD-", _symbol))
        );

        holder = _holder;
        underlyingDealToken = _underlyingDealToken;
        underlyingDealTokenDecimals = IERC20(_underlyingDealToken).decimals();
        underlyingDealTokenTotal = _underlyingDealTokenTotal;
        maxTotalSupply = _poolTokenMaxPurchaseAmount;
        
        aelinPool = msg.sender;
        vestingCliff = block.timestamp + _proRataRedemptionPeriod + _openRedemptionPeriod + _vestingCliff;
        vestingPeriod = _vestingPeriod;
        vestingExpiry = vestingCliff + _vestingPeriod;
        proRataRedemptionPeriod = _proRataRedemptionPeriod;
        openRedemptionPeriod = _openRedemptionPeriod;

        calledInitialize = true;
        depositComplete = false;

        // NOTE calculate the amount of underlying deal tokens you get per wrapped pool token accepted
        // Also, 1 wrapped pool token = 1 wrapped deal token
        underlyingPerPoolExchangeRate = _underlyingDealTokenTotal * 1e18 / _poolTokenMaxPurchaseAmount;
    }

    modifier initOnce () {
        require(calledInitialize == false, "can only initialize once");
        _;
    }

    modifier finalizeDepositOnce () {
        require(depositComplete == false, "deposit already complete");
        _;
    }

    // NOTE if the deposit was completed with a transfer instead of this method, 
    // the deposit can be finalized by calling this method with amount 0;
    function depositUnderlying(uint _underlyingDealTokenAmount) external finalizeDepositOnce returns (bool) {
        if (IERC20(underlyingDealToken).balanceOf(address(this)) + _underlyingDealTokenAmount >= underlyingDealTokenTotal) {
            depositComplete = true;
        }
        if (_underlyingDealTokenAmount > 0) {
            _safeTransferFrom(underlyingDealToken, msg.sender, address(this), _underlyingDealTokenAmount);
            emit DepositDealTokens(underlyingDealToken, msg.sender, address(this), _underlyingDealTokenAmount);
        }
        if (depositComplete == true) {
            proRataRedemptionStart = block.timestamp;
            proRataRedemptionExpiry = block.timestamp + proRataRedemptionPeriod;

            if (openRedemptionPeriod > 0) {
                openRedemptionStart = proRataRedemptionExpiry;
                openRedemptionExpiry = proRataRedemptionExpiry + openRedemptionPeriod;
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
    function withdraw() external onlyHolder {
        uint withdrawAmount = IERC20(underlyingDealToken).balanceOf(address(this)) - underlyingDealTokenTotal - totalUnderlyingClaimed;
        _safeTransfer(underlyingDealToken, holder, withdrawAmount);
        emit WithdrawUnderlyingDealTokens(underlyingDealToken, holder, address(this), withdrawAmount);
    }

    function withdrawExpiry() external onlyHolder {
        require(proRataRedemptionExpiry > 0, "redemption period not started");
        require(
            openRedemptionExpiry > 0 ?
                block.timestamp > openRedemptionExpiry :
                block.timestamp > proRataRedemptionExpiry,
            "redeem window still active"
        );
        uint withdrawAmount = IERC20(underlyingDealToken).balanceOf(address(this)) - (underlyingPerPoolExchangeRate * totalSupply / 1e18);
        _safeTransfer(underlyingDealToken, holder, withdrawAmount);
        emit WithdrawUnderlyingDealTokens(underlyingDealToken, holder, address(this), withdrawAmount);
    }
    
    modifier onlyHolder() {
        require(msg.sender == holder, "only holder can access");
        _;
    }
    
    modifier onlyPool() {
        require(msg.sender == aelinPool, "only AelinPool can access");
        _;
    }
    
    mapping(address => uint) public lastClaim;
    
    function underlyingDealTokensClaimable(address purchaser) external view returns (uint) {
        uint maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        if (maxTime > vestingCliff || (maxTime == vestingCliff && vestingPeriod == 0 && lastClaim[purchaser] == 0)) {
            uint lastClaimed = lastClaim[purchaser];
            if (lastClaimed == 0) {
                lastClaimed = vestingCliff;
            }
            if (lastClaimed >= maxTime && vestingPeriod != 0) {
                return 0;
            } else {
                uint timeElapsed = maxTime - lastClaimed;
                uint dealTokensClaimable = vestingPeriod == 0 ? balanceOf[purchaser] : balanceOf[purchaser] * timeElapsed / vestingPeriod;
                return underlyingPerPoolExchangeRate * dealTokensClaimable / 1e18;
            }
        } else {
            return 0;
        }
    }
    
    function claim(address from) external {
        _claim(from, from);
    }
    
    function claimAndAllocate(address recipient) external {
        _claim(msg.sender, recipient);
    }
    
    function _claim(address from, address recipient) internal returns (uint dealTokensClaimed) {
        require(balanceOf[from] > 0, "nothing to claim");
        uint maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        if (maxTime > vestingCliff || (maxTime == vestingCliff && vestingPeriod == 0 && lastClaim[from] == 0)) {
            if (lastClaim[from] == 0) {
                lastClaim[from] = vestingCliff;
            }
            uint timeElapsed = maxTime - lastClaim[from];
            uint dealTokensClaimed = vestingPeriod == 0 ? balanceOf[from] : balanceOf[from] * timeElapsed / vestingPeriod;
            uint underlyingDealTokensClaimed = underlyingPerPoolExchangeRate * dealTokensClaimed / 1e18;

            if (dealTokensClaimed > 0) {
                _burn(from, dealTokensClaimed);
                _safeTransfer(underlyingDealToken, recipient, underlyingDealTokensClaimed);
                totalUnderlyingClaimed += underlyingDealTokensClaimed;
                emit ClaimedUnderlyingDealTokens(underlyingDealToken, from, recipient, underlyingDealTokensClaimed);
            }
            lastClaim[from] = maxTime;
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

    function transferFrom(address src, address dst, uint amount) external override returns (bool) {
        address spender = msg.sender;
        uint spenderAllowance = allowance[src][spender];

        if (spender != src && spenderAllowance != type(uint).max) {
            uint newAllowance = spenderAllowance - amount;
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
        require(balanceOf[src] >= amount, "not enough to transfer");
        _claim(src, src);
        _claim(dst, dst);
        balanceOf[dst] += amount;
        
        emit Transfer(src, dst, amount);
    }

    event DealFullyFunded(address indexed poolAddress, address indexed dealAddress, uint proRataRedemptionStart, uint proRataRedemptionExpiry, uint openRedemptionStart, uint openRedemptionExpiry);
    event DepositDealTokens(address indexed underlyingDealTokenAddress, address indexed depositor, address indexed dealContract, uint underlyingDealTokenAmount);
    event WithdrawUnderlyingDealTokens(address indexed underlyingDealTokenAddress, address indexed depositor, address indexed dealContract, uint underlyingDealTokenAmount);
    event ClaimedUnderlyingDealTokens(address indexed underlyingDealTokenAddress, address indexed from, address indexed recipient, uint underlyingDealTokensClaimed);
    event MintDealTokens(address indexed dealContract, address indexed recipient, uint dealTokenAmount);
}