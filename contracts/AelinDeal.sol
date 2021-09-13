// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract AelinDeal is AelinERC20 {
    uint public maxTotalSupply;

    address public underlyingDealToken;
    uint public underlyingDealTokenDecimals;
    uint public underlyingDealTokenTotal;
    uint public totalUnderlyingClaimed;
    address public holder;
    address public futureHolder;

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
        underlyingDealTokenDecimals = IERC20Decimals(_underlyingDealToken).decimals();
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
        emit SetHolder(_holder);
    }

    modifier initOnce () {
        require(calledInitialize == false, "can only initialize once");
        _;
    }

    modifier finalizeDepositOnce () {
        require(depositComplete == false, "deposit already complete");
        _;
    }

    function setHolder(address _holder) external onlyHolder  {
        futureHolder = _holder;
    }
    
    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit SetHolder(futureHolder);
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
    // TODO the holder can deposit less if people withdraw after the deal is created but before the deal is funded.
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
        uint withdrawAmount = IERC20(underlyingDealToken).balanceOf(address(this)) - (underlyingPerPoolExchangeRate * totalSupply() / 1e18);
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
                uint dealTokensClaimable = vestingPeriod == 0 ? balanceOf(purchaser) : balanceOf(purchaser) * timeElapsed / vestingPeriod;
                return underlyingPerPoolExchangeRate * dealTokensClaimable / 1e18;
            }
        } else {
            return 0;
        }
    }
    
    function claim(address recipient) public returns (uint) {
        if (balanceOf(recipient) > 0) {
            uint maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
            if (maxTime > vestingCliff || (maxTime == vestingCliff && vestingPeriod == 0 && lastClaim[recipient] == 0)) {
                if (lastClaim[recipient] == 0) {
                    lastClaim[recipient] = vestingCliff;
                }
                uint timeElapsed = maxTime - lastClaim[recipient];
                uint dealTokensClaimed = vestingPeriod == 0 ? balanceOf(recipient) : balanceOf(recipient) * timeElapsed / vestingPeriod;
                uint underlyingDealTokensClaimed = underlyingPerPoolExchangeRate * dealTokensClaimed / 1e18;

                if (dealTokensClaimed > 0) {
                    _burn(recipient, dealTokensClaimed);
                    _safeTransfer(underlyingDealToken, recipient, underlyingDealTokensClaimed);
                    totalUnderlyingClaimed += underlyingDealTokensClaimed;
                    emit ClaimedUnderlyingDealTokens(underlyingDealToken, recipient, underlyingDealTokensClaimed);
                }
                lastClaim[recipient] = maxTime;
                return dealTokensClaimed;
            }
        }
        return 0;
    }
    
    function mint(address dst, uint dealTokenAmount) external onlyPool {
        _mint(dst, dealTokenAmount);
        emit MintDealTokens(address(this), dst, dealTokenAmount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        claim(from);
        claim(to);
    }

    event SetHolder(address indexed holder);
    event DealFullyFunded(
        address indexed poolAddress,
        address indexed dealAddress,
        uint proRataRedemptionStart,
        uint proRataRedemptionExpiry,
        uint openRedemptionStart,
        uint openRedemptionExpiry
    );
    event DepositDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        address indexed dealContract,
        uint underlyingDealTokenAmount
    );
    event WithdrawUnderlyingDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        address indexed dealContract,
        uint underlyingDealTokenAmount
    );
    event ClaimedUnderlyingDealTokens(
        address indexed underlyingDealTokenAddress,
        address indexed recipient,
        uint underlyingDealTokensClaimed
    );
    event MintDealTokens(address indexed dealContract, address indexed recipient, uint dealTokenAmount);
}