// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./MinimalProxyFactory.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory {
    address public purchaseToken;
    uint public purchaseTokenCap;
    uint public purchaseTokenDecimals;
    uint public proRataConversion;

    uint public sponsorFee;
    address public sponsor;
    address public futureSponsor;

    uint constant BASE = 100000;
    uint constant MAX_SPONSOR_FEE = 98000;
    uint constant AELIN_FEE = 2000;

    uint public purchaseExpiry;
    uint public poolExpiry;

    bool public calledInitialize = false;
    bool public dealCreated = false;

    address public aelinDealLogicAddress;
    address public aelinDealStorageProxy;
    address public holder;
    mapping(address => bool) public openPeriodEligible;
    mapping(address => uint) public dealAmountAllocated;

    string private storedName;
    string private storedSymbol;


    // @TODO update with correct addresses
    address constant AELIN_REWARDS = 0x0000000000000000000000000000000000000000;

    constructor () {}
    
    function initialize (
        string memory _name,
        string memory _symbol,
        uint _purchaseTokenCap,
        address _purchaseToken,
        uint _duration,
        uint _sponsorFee,
        address _sponsor,
        uint _purchaseExpiry,
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
        purchaseTokenDecimals = IERC20(_purchaseToken).decimals();
        require(365 days >= _duration, "max 1 year duration");
        poolExpiry = block.timestamp + _duration;
        require(30 minutes <= _purchaseExpiry, "min 30 minutes purchase expiry");
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
    
    function setSponsor(address _sponsor) external onlySponsor  {
        futureSponsor = _sponsor;
    }
    
    function acceptSponsor() external {
        require(msg.sender == futureSponsor, "only future sponsor can access");
        sponsor = futureSponsor;
        emit SetSponsor(futureSponsor);
    }

    function createDeal(
        address _underlyingDealToken,
        uint _purchaseTokenTotalForDeal,
        uint _underlyingDealTokenTotal,
        uint _vestingPeriod,
        uint _vestingCliff,
        uint _proRataRedemptionPeriod,
        uint _openRedemptionPeriod,
        address _holder
    ) external onlySponsor dealNotCreated returns (address) {
        // enforce called after purchase expiry??
        require(30 minutes <= _proRataRedemptionPeriod, "30 mins is min prorata period");
        uint poolTokenMaxPurchaseAmount = convertUnderlyingToAelinAmount(
            _purchaseTokenTotalForDeal,
            purchaseTokenDecimals
        );
        require(poolTokenMaxPurchaseAmount <= totalSupply, "not enough funds available");
        proRataConversion = poolTokenMaxPurchaseAmount * 1e18 / totalSupply;
        if (proRataConversion == 1e18) {
            require(0 minutes == _openRedemptionPeriod, "deal is 1:1, set open to 0");
        } else {
            require(30 minutes <= _openRedemptionPeriod, "30 mins is min open period");
        }

        poolExpiry = block.timestamp;
        holder = _holder;
        dealCreated = true;

        AelinDeal aelinDeal = AelinDeal(_cloneAsMinimalProxy(aelinDealLogicAddress, "Could not create new deal"));
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
        _acceptDealTokens(msg.sender, 0, true, false);
    }

    function acceptMaxDealTokensAndAllocate(address recipient) external {
        _acceptDealTokens(recipient, 0, true, true);
    }

    function acceptDealTokens(uint poolTokenAmount) external {
        _acceptDealTokens(msg.sender, poolTokenAmount, false, false);
    }

    function acceptDealTokensAndAllocate(address recipient, uint poolTokenAmount) external {
        _acceptDealTokens(recipient, poolTokenAmount, false, true);
    }

    function maxProRataAvail(address purchaser) public view returns (uint) {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (balanceOf[purchaser] == 0 || dealCreated == false || block.timestamp >= aelinDeal.proRataRedemptionExpiry()) {
            return 0;
        }
        uint amountAccepted = aelinDeal.balanceOf(purchaser) * BASE / (BASE - AELIN_FEE - sponsorFee) - dealAmountAllocated[purchaser];
        return proRataConversion * (balanceOf[purchaser] + amountAccepted) / 1e18 - amountAccepted;
    }

    function maxOpenAvail(address purchaser) internal view returns (uint) {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        return balanceOf[purchaser] + aelinDeal.totalSupply() <= aelinDeal.maxTotalSupply() ?
            balanceOf[purchaser] :
            aelinDeal.maxTotalSupply() - aelinDeal.totalSupply();
    }

    function _acceptDealTokens(address recipient, uint poolTokenAmount, bool useMax, bool isAllocated) internal dealAlreadyCreated {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (block.timestamp >= aelinDeal.proRataRedemptionStart() && block.timestamp < aelinDeal.proRataRedemptionExpiry()) {
            _acceptDealTokensProRata(recipient, poolTokenAmount, useMax, isAllocated);
        } else if (aelinDeal.openRedemptionStart() > 0 && block.timestamp < aelinDeal.openRedemptionExpiry()) {
            _acceptDealTokensOpen(recipient, poolTokenAmount, useMax, isAllocated);
        } else {
            revert("outside of redeem window");
        }
    }

    function _acceptDealTokensProRata(address recipient, uint poolTokenAmount, bool useMax, bool isAllocated) internal {
        uint maxProRata = maxProRataAvail(msg.sender);
        if (!useMax) {
            require(poolTokenAmount <= maxProRata, "accepting more than share");
        }
        uint acceptAmount = useMax ? maxProRata : poolTokenAmount;
        acceptDealLogic(recipient, acceptAmount, isAllocated);
        if (proRataConversion != 1e18 && maxProRataAvail(msg.sender) == 0) {
            openPeriodEligible[msg.sender] = true;
        }
    }

    function _acceptDealTokensOpen(address recipient, uint poolTokenAmount, bool useMax, bool isAllocated) internal {
        require(openPeriodEligible[msg.sender], "ineligible: didn't max pro rata");
        uint maxOpen = maxOpenAvail(msg.sender);
        uint acceptAmount = useMax ? maxOpen : poolTokenAmount;
        if (!useMax) {
            require(acceptAmount <= maxOpen, "accepting more than share");
        }
        acceptDealLogic(recipient, acceptAmount, isAllocated);
    }

    function acceptDealLogic(address recipient, uint poolTokenAmount, bool isAllocated) internal {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (isAllocated) {
            dealAmountAllocated[recipient] += poolTokenAmount;
        }
        _burn(msg.sender, poolTokenAmount);
        uint aelinFee = poolTokenAmount * AELIN_FEE / BASE;
        uint sponsorFee = poolTokenAmount * sponsorFee / BASE;

        aelinDeal.mint(sponsor, sponsorFee);
        aelinDeal.mint(AELIN_REWARDS, aelinFee);
        aelinDeal.mint(recipient, poolTokenAmount - (sponsorFee + aelinFee));

        uint underlyingToHolderAmt = convertAelinToUnderlyingAmount(poolTokenAmount, purchaseTokenDecimals);
        _safeTransfer(purchaseToken, holder, underlyingToHolderAmt);
        emit AcceptDeal(recipient, address(this), aelinDealStorageProxy, poolTokenAmount, sponsorFee, aelinFee, underlyingToHolderAmt);
    }

    function purchasePoolTokens(uint purchaseTokenAmount) external {
        _purchasePoolTokens(msg.sender, purchaseTokenAmount);
    }

    function purchasePoolTokensAndAllocate(address recipient, uint purchaseTokenAmount) external {
        _purchasePoolTokens(recipient, purchaseTokenAmount);
    }

    // NOTE you have to enter the precise amount which can get precarious as a deal fills
    // maybe we should add another method to just take whatever is left?
    function _purchasePoolTokens(address recipient, uint purchaseTokenAmount) internal {
        require(dealCreated == false && block.timestamp < purchaseExpiry, "not in purchase window");
        uint poolTokenAmount = convertUnderlyingToAelinAmount(purchaseTokenAmount, purchaseTokenDecimals);
        uint poolTokenCap = convertUnderlyingToAelinAmount(purchaseTokenCap, purchaseTokenDecimals);
        require(purchaseTokenCap == 0 || (totalSupply + poolTokenAmount) <= poolTokenCap, "cap has been exceeded");
        _safeTransferFrom(purchaseToken, msg.sender, address(this), purchaseTokenAmount);
        _mint(recipient, poolTokenAmount);
        emit PurchasePoolToken(recipient, msg.sender, address(this), purchaseTokenAmount, poolTokenAmount);
    }

    function withdrawMaxFromPool() external {
        _withdraw(balanceOf[msg.sender]);
    }

    function withdrawFromPool(uint poolTokenAmount) external {
        _withdraw(poolTokenAmount);
    }

    function _withdraw(uint poolTokenAmount) internal {
        require(block.timestamp > poolExpiry, "not yet withdraw period");
        _burn(msg.sender, poolTokenAmount);
        uint purchaseWithdrawAmount = convertAelinToUnderlyingAmount(poolTokenAmount, purchaseTokenDecimals);
        _safeTransfer(purchaseToken, msg.sender, purchaseWithdrawAmount);
        emit WithdrawFromPool(msg.sender, address(this), purchaseWithdrawAmount, poolTokenAmount);
    }

    function maxDealAccept(address purchaser) external view returns (uint) {
        AelinDeal aelinDeal = AelinDeal(aelinDealStorageProxy);
        if (
            dealCreated == false ||
            block.timestamp >= aelinDeal.proRataRedemptionExpiry() && aelinDeal.openRedemptionStart() == 0 ||
            block.timestamp > aelinDeal.openRedemptionExpiry() && aelinDeal.openRedemptionStart() != 0
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

    function maxPoolPurchase() external view returns (uint) {
        if (dealCreated == true || block.timestamp >= purchaseExpiry) {
            return 0;
        }
        if (purchaseTokenCap == 0) {
            return type(uint).max;
        } else {
            uint poolTokenCap = convertUnderlyingToAelinAmount(purchaseTokenCap, purchaseTokenDecimals);
            uint remainingAmount = poolTokenCap - totalSupply;
            return convertAelinToUnderlyingAmount(remainingAmount, purchaseTokenDecimals);
        }
    }

    event SetSponsor(address indexed sponsor);
    event PurchasePoolToken(address indexed recipient, address indexed purchaser, address indexed poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event WithdrawFromPool(address indexed purchaser, address indexed poolAddress, uint purchaseTokenAmount, uint poolTokenAmount);
    event AcceptDeal(
        address indexed purchaser,
        address indexed poolAddress,
        address indexed dealAddress,
        uint poolTokenAmount,
        uint sponsorFee,
        uint aelinFee,
        uint underlyingToHolderAmt
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
        uint purchaseTokenTotalForDeal,
        uint underlyingDealTokenTotal,
        uint vestingPeriod,
        uint vestingCliff,
        uint proRataRedemptionPeriod,
        uint openRedemptionPeriod,
        address indexed holder
    );
}
