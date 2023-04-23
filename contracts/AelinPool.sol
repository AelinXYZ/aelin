// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./AelinDeal.sol";
import "./interfaces/IAelinPool.sol";
import "./libraries/NftCheck.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory, IAelinPool {
    using SafeERC20 for IERC20;
    uint256 constant BASE = 100 * 10 ** 18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 constant AELIN_FEE = 2 * 10 ** 18;
    uint256 constant ID_RANGES_MAX_LENGTH = 10;
    uint8 constant MAX_DEALS = 5;

    uint8 public numberOfDeals;
    uint8 public purchaseTokenDecimals;
    address public purchaseToken;
    uint256 public purchaseTokenCap;
    uint256 public proRataConversion;

    uint256 public sponsorFee;
    address public sponsor;
    address public futureSponsor;
    address public poolFactory;

    uint256 public purchaseExpiry;
    uint256 public poolExpiry;
    uint256 public holderFundingExpiry;
    uint256 public totalAmountAccepted;
    uint256 public totalAmountWithdrawn;
    uint256 public purchaseTokenTotalForDeal;
    uint256 public totalSponsorFeeAmount;

    bool private calledInitialize;
    bool private sponsorClaimed;

    address public aelinTreasuryAddress;
    address public aelinDealLogicAddress;
    address public aelinEscrowLogicAddress;
    AelinDeal public aelinDeal;
    address public holder;

    mapping(address => uint256) public amountAccepted;
    mapping(address => uint256) public amountWithdrawn;
    mapping(address => bool) public openPeriodEligible;
    mapping(address => uint256) public allowList;
    // collectionAddress -> NftCollectionRules struct
    mapping(address => NftCollectionRules) public nftCollectionDetails;

    /**
     * @dev For 721, it is used for blacklisting the tokenId of a collection
     * and for 1155, it is used for identifying the eligible tokenIds for
     * participating in the pool
     */
    mapping(address => mapping(uint256 => bool)) public nftId;
    bool public hasNftList;
    bool public hasAllowList;

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
     * - max sponsor fee is 15000 representing 15%
     */
    function initialize(
        PoolData calldata _poolData,
        address _sponsor,
        address _aelinDealLogicAddress,
        address _aelinTreasuryAddress,
        address _aelinEscrowLogicAddress
    ) external initOnce {
        require(
            30 minutes <= _poolData.purchaseDuration && 30 days >= _poolData.purchaseDuration,
            "outside purchase expiry window"
        );
        require(365 days >= _poolData.duration, "max 1 year duration");
        require(_poolData.sponsorFee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");
        purchaseTokenDecimals = IERC20Decimals(_poolData.purchaseToken).decimals();
        require(purchaseTokenDecimals <= DEAL_TOKEN_DECIMALS, "too many token decimals");
        storedName = _poolData.name;
        storedSymbol = _poolData.symbol;
        poolFactory = msg.sender;

        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aePool-", _poolData.name)),
            string(abi.encodePacked("aeP-", _poolData.symbol)),
            purchaseTokenDecimals
        );

        purchaseTokenCap = _poolData.purchaseTokenCap;
        purchaseToken = _poolData.purchaseToken;
        purchaseExpiry = block.timestamp + _poolData.purchaseDuration;
        poolExpiry = purchaseExpiry + _poolData.duration;
        sponsorFee = _poolData.sponsorFee;
        sponsor = _sponsor;
        aelinEscrowLogicAddress = _aelinEscrowLogicAddress;
        aelinDealLogicAddress = _aelinDealLogicAddress;
        aelinTreasuryAddress = _aelinTreasuryAddress;

        address[] memory allowListAddresses = _poolData.allowListAddresses;
        uint256[] memory allowListAmounts = _poolData.allowListAmounts;

        if (allowListAddresses.length > 0 || allowListAmounts.length > 0) {
            require(
                allowListAddresses.length == allowListAmounts.length,
                "allowListAddresses and allowListAmounts arrays should have the same length"
            );
            for (uint256 i; i < allowListAddresses.length; ++i) {
                allowList[allowListAddresses[i]] = allowListAmounts[i];
                emit AllowlistAddress(allowListAddresses[i], allowListAmounts[i]);
            }
            hasAllowList = true;
        }

        NftCollectionRules[] calldata nftCollectionRules = _poolData.nftCollectionRules;

        if (nftCollectionRules.length > 0) {
            // if the first address supports 721, the entire pool only supports 721
            if (NftCheck.supports721(nftCollectionRules[0].collectionAddress)) {
                for (uint256 i; i < nftCollectionRules.length; ++i) {
                    require(NftCheck.supports721(nftCollectionRules[i].collectionAddress), "can only contain 721");

                    uint256 rangesLength = nftCollectionRules[i].idRanges.length;
                    require(rangesLength <= ID_RANGES_MAX_LENGTH, "too many ranges");

                    for (uint256 j; j < rangesLength; j++) {
                        require(
                            nftCollectionRules[i].idRanges[j].begin <= nftCollectionRules[i].idRanges[j].end,
                            "begin greater than end"
                        );
                    }

                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];
                    emit PoolWith721(nftCollectionRules[i].collectionAddress, nftCollectionRules[i].purchaseAmount);
                }
                hasNftList = true;
            }
            // if the first address supports 1155, the entire pool only supports 1155
            else if (NftCheck.supports1155(nftCollectionRules[0].collectionAddress)) {
                for (uint256 i; i < nftCollectionRules.length; ++i) {
                    require(NftCheck.supports1155(nftCollectionRules[i].collectionAddress), "can only contain 1155");
                    require(nftCollectionRules[i].purchaseAmount == 0, "purchase amt must be 0 for 1155");
                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];

                    for (uint256 j; j < nftCollectionRules[i].tokenIds.length; ++j) {
                        nftId[nftCollectionRules[i].collectionAddress][nftCollectionRules[i].tokenIds[j]] = true;
                    }
                    emit PoolWith1155(
                        nftCollectionRules[i].collectionAddress,
                        nftCollectionRules[i].purchaseAmount,
                        nftCollectionRules[i].tokenIds,
                        nftCollectionRules[i].minTokensEligible
                    );
                }
                hasNftList = true;
            } else {
                revert("collection is not compatible");
            }
        }

        emit SetSponsor(_sponsor);
    }

    /**
     * @dev allows anyone to become a purchaser by sending purchase tokens
     * in exchange for pool tokens
     *
     * Requirements:
     * - the deal is in the purchase expiry window
     * - the cap has not been exceeded
     */
    function purchasePoolTokens(uint256 _purchaseTokenAmount) external nonReentrant {
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(!hasNftList, "has NFT list");
        if (hasAllowList) {
            require(_purchaseTokenAmount <= allowList[msg.sender], "more than allocation");
            allowList[msg.sender] -= _purchaseTokenAmount;
        }
        uint256 currentBalance = IERC20(purchaseToken).balanceOf(address(this));
        IERC20(purchaseToken).safeTransferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = balanceAfterTransfer - currentBalance;
        if (purchaseTokenCap > 0) {
            uint256 totalPoolAfter = totalSupply() + purchaseTokenAmount;
            require(totalPoolAfter <= purchaseTokenCap, "cap has been exceeded");
            if (totalPoolAfter == purchaseTokenCap) {
                purchaseExpiry = block.timestamp;
            }
        }

        _mint(msg.sender, purchaseTokenAmount);
        emit PurchasePoolToken(msg.sender, purchaseTokenAmount);
    }

    /**
     * @dev allows anyone to become a purchaser with a qualified erc721
     * nft in the pool depending on the scenarios
     *
     * Scenarios:
     * 1. each wallet holding a qualified NFT to deposit an unlimited amount of purchase tokens
     * 2. certain amount of Investment tokens per qualified NFT held
     */

    function purchasePoolTokensWithNft(
        NftPurchaseList[] calldata _nftPurchaseList,
        uint256 _purchaseTokenAmount
    ) external nonReentrant {
        uint256 collectionLength = _nftPurchaseList.length;

        require(hasNftList, "pool does not have an NFT list");
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(collectionLength > 0, "must provide purchase list");

        //An array of arrays that correspond to the max purchase amount for each (collection, tokenId) pairing
        uint256[][] memory maxPurchaseTokenAmounts = new uint256[][](collectionLength);

        NftPurchaseList memory nftPurchaseList;
        address _collectionAddress;
        uint256[] memory _tokenIds;
        NftCollectionRules memory nftCollectionRules;

        //Iterate over the collections
        for (uint256 i; i < collectionLength; ++i) {
            nftPurchaseList = _nftPurchaseList[i];
            _collectionAddress = nftPurchaseList.collectionAddress;
            _tokenIds = nftPurchaseList.tokenIds;
            nftCollectionRules = nftCollectionDetails[_collectionAddress];

            uint256 tokenIdsLength = _tokenIds.length;
            //Dummy array used for this iteration token ids
            //Must be re-declared here each loop because the length may vary
            uint256[] memory maxPurchaseTokensAmountForCollection = new uint256[](tokenIdsLength);

            require(_collectionAddress != address(0), "collection should not be null");
            require(nftCollectionRules.collectionAddress == _collectionAddress, "collection not in the pool");

            //Iterate over the token ids
            for (uint256 j; j < tokenIdsLength; ++j) {
                if (NftCheck.supports721(_collectionAddress)) {
                    require(IERC721(_collectionAddress).ownerOf(_tokenIds[j]) == msg.sender, "has to be the token owner");
                    // If there are no ranges then no need to check whether token Id is within them
                    // Or whether there are any rangeAmounts
                    if (nftCollectionRules.idRanges.length > 0) {
                        //Gets a boolean for whether token Id is in range and what the range amount is if there is one
                        (bool isTokenIdInRange, uint256 rangeAmountForTokenId) = getRangeData(
                            _tokenIds[j],
                            nftCollectionRules.idRanges
                        );
                        require(isTokenIdInRange, "tokenId not in range");

                        //if there's a range amount for this token id, then set that as the max for its element
                        if (rangeAmountForTokenId != 0) {
                            maxPurchaseTokensAmountForCollection[j] = rangeAmountForTokenId;
                        } else {
                            //Otherwise defer to purchaseAmount
                            if (nftCollectionRules.purchaseAmount == 0) {
                                maxPurchaseTokensAmountForCollection[j] = type(uint256).max;
                            } else {
                                maxPurchaseTokensAmountForCollection[j] = nftCollectionRules.purchaseAmount;
                            }
                        }
                    } else {
                        if (nftCollectionRules.purchaseAmount == 0) {
                            maxPurchaseTokensAmountForCollection[j] = type(uint256).max;
                        } else {
                            maxPurchaseTokensAmountForCollection[j] = nftCollectionRules.purchaseAmount;
                        }
                    }

                    require(!nftId[_collectionAddress][_tokenIds[j]], "tokenId already used");
                    nftId[_collectionAddress][_tokenIds[j]] = true;
                    emit BlacklistNFT(_collectionAddress, _tokenIds[j]);
                }

                if (NftCheck.supports1155(_collectionAddress)) {
                    require(nftId[_collectionAddress][_tokenIds[j]], "tokenId not in the pool");
                    require(
                        IERC1155(_collectionAddress).balanceOf(msg.sender, _tokenIds[j]) >=
                            nftCollectionRules.minTokensEligible[j],
                        "erc1155 balance too low"
                    );

                    //All 1155s are allowed unlimited purchases per token Id
                    maxPurchaseTokensAmountForCollection[j] = type(uint256).max;
                }
            }
            maxPurchaseTokenAmounts[i] = maxPurchaseTokensAmountForCollection;
        }

        uint256 maxPurchaseTokenAmount = getMaxPurchaseTokenAmount(maxPurchaseTokenAmounts);
        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount should be less the max allocation");

        uint256 amountBefore = IERC20(purchaseToken).balanceOf(address(this));
        IERC20(purchaseToken).safeTransferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 amountAfter = IERC20(purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = amountAfter - amountBefore;

        if (purchaseTokenCap > 0) {
            uint256 totalPoolAfter = totalSupply() + purchaseTokenAmount;
            require(totalPoolAfter <= purchaseTokenCap, "cap has been exceeded");
            if (totalPoolAfter == purchaseTokenCap) {
                purchaseExpiry = block.timestamp;
            }
        }

        _mint(msg.sender, purchaseTokenAmount);
        emit PurchasePoolToken(msg.sender, purchaseTokenAmount);
    }

    function getMaxPurchaseTokenAmount(uint256[][] memory maxPurchaseTokenAmounts) internal pure returns (uint256) {
        uint256 collectionLength = maxPurchaseTokenAmounts.length;
        uint256 tokenIdsPerCollectionLength;
        uint256 runningTotal;

        for (uint256 i; i < collectionLength; i++) {
            tokenIdsPerCollectionLength = maxPurchaseTokenAmounts[i].length;
            for (uint256 j; j < tokenIdsPerCollectionLength; j++) {
                if (maxPurchaseTokenAmounts[i][j] == type(uint256).max) {
                    //If there are any unlimited purchase amounts then return max
                    return type(uint256).max;
                } else {
                    runningTotal += maxPurchaseTokenAmounts[i][j];
                }
            }
        }
        return runningTotal;
    }

    function getRangeData(uint256 _tokenId, IdRange[] memory _idRanges) internal pure returns (bool, uint256) {
        for (uint256 i; i < _idRanges.length; i++) {
            if (_tokenId >= _idRanges[i].begin && _tokenId <= _idRanges[i].end) {
                return (true, _idRanges[i].rangeAmount);
            }
        }
        return (false, 0);
    }

    function _blackListCheck721(address _collectionAddress, uint256[] memory _tokenIds) internal {
        for (uint256 i; i < _tokenIds.length; ++i) {
            require(IERC721(_collectionAddress).ownerOf(_tokenIds[i]) == msg.sender, "has to be the token owner");
            require(!nftId[_collectionAddress][_tokenIds[i]], "tokenId already used");
            nftId[_collectionAddress][_tokenIds[i]] = true;
            emit BlacklistNFT(_collectionAddress, _tokenIds[i]);
        }
    }

    function _eligibilityCheck1155(
        address _collectionAddress,
        uint256[] memory _tokenIds,
        NftCollectionRules memory _nftCollectionRules
    ) internal view {
        for (uint256 i; i < _tokenIds.length; ++i) {
            require(nftId[_collectionAddress][_tokenIds[i]], "tokenId not in the pool");
            require(
                IERC1155(_collectionAddress).balanceOf(msg.sender, _tokenIds[i]) >= _nftCollectionRules.minTokensEligible[i],
                "erc1155 balance too low"
            );
        }
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

    function withdrawFromPool(uint256 _purchaseTokenAmount) external {
        _withdraw(_purchaseTokenAmount);
    }

    /**
     * @dev purchasers can withdraw at the end of the pool expiry period if
     * no deal was presented or they can withdraw after the holder funding period
     * if they do not like a deal
     */
    function _withdraw(uint256 _purchaseTokenAmount) internal {
        require(_purchaseTokenAmount <= balanceOf(msg.sender), "input larger than balance");
        require(block.timestamp >= poolExpiry, "not yet withdraw period");
        if (holderFundingExpiry > 0) {
            require(block.timestamp > holderFundingExpiry || aelinDeal.depositComplete(), "cant withdraw in funding period");
        }
        amountWithdrawn[msg.sender] += _purchaseTokenAmount;
        totalAmountWithdrawn += _purchaseTokenAmount;
        _burn(msg.sender, _purchaseTokenAmount);
        IERC20(purchaseToken).safeTransfer(msg.sender, _purchaseTokenAmount);
        emit WithdrawFromPool(msg.sender, _purchaseTokenAmount);
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
        uint256 _vestingCliffPeriod,
        uint256 _proRataRedemptionPeriod,
        uint256 _openRedemptionPeriod,
        address _holder,
        uint256 _holderFundingDuration
    ) external onlySponsor dealReady returns (address) {
        require(numberOfDeals < MAX_DEALS, "too many deals");
        require(_holder != address(0), "cant pass null holder address");
        require(_underlyingDealToken != address(0), "cant pass null token address");
        require(block.timestamp >= purchaseExpiry, "pool still in purchase mode");
        require(
            30 minutes <= _proRataRedemptionPeriod && 30 days >= _proRataRedemptionPeriod,
            "30 mins - 30 days for prorata"
        );
        require(1825 days >= _vestingCliffPeriod, "max 5 year cliff");
        require(1825 days >= _vestingPeriod, "max 5 year vesting");
        require(30 minutes <= _holderFundingDuration && 30 days >= _holderFundingDuration, "30 mins - 30 days for holder");
        require(_purchaseTokenTotalForDeal <= totalSupply(), "not enough funds available");
        proRataConversion = (_purchaseTokenTotalForDeal * 1e18) / totalSupply();
        if (proRataConversion == 1e18) {
            require(0 minutes == _openRedemptionPeriod, "deal is 1:1, set open to 0");
        } else {
            require(30 minutes <= _openRedemptionPeriod && 30 days >= _openRedemptionPeriod, "30 mins - 30 days for open");
        }

        numberOfDeals += 1;
        poolExpiry = block.timestamp;
        holder = _holder;
        holderFundingExpiry = block.timestamp + _holderFundingDuration;
        purchaseTokenTotalForDeal = _purchaseTokenTotalForDeal;
        uint256 maxDealTotalSupply = _convertPoolToDeal(_purchaseTokenTotalForDeal, purchaseTokenDecimals);

        address aelinDealStorageProxy = _cloneAsMinimalProxy(aelinDealLogicAddress, "Could not create new deal");
        aelinDeal = AelinDeal(aelinDealStorageProxy);
        IAelinDeal.DealData memory dealData = IAelinDeal.DealData(
            _underlyingDealToken,
            _underlyingDealTokenTotal,
            _vestingPeriod,
            _vestingCliffPeriod,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _holder,
            maxDealTotalSupply,
            holderFundingExpiry
        );

        aelinDeal.initialize(storedName, storedSymbol, dealData, aelinTreasuryAddress, aelinEscrowLogicAddress);

        emit CreateDeal(
            string(abi.encodePacked("aeDeal-", storedName)),
            string(abi.encodePacked("aeD-", storedSymbol)),
            sponsor,
            aelinDealStorageProxy
        );

        emit DealDetail(
            aelinDealStorageProxy,
            _underlyingDealToken,
            _purchaseTokenTotalForDeal,
            _underlyingDealTokenTotal,
            _vestingPeriod,
            _vestingCliffPeriod,
            _proRataRedemptionPeriod,
            _openRedemptionPeriod,
            _holder,
            _holderFundingDuration
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

    function acceptDealTokens(uint256 _poolTokenAmount) external {
        _acceptDealTokens(msg.sender, _poolTokenAmount, false);
    }

    function _acceptDealTokens(address _recipient, uint256 _poolTokenAmount, bool _useMax) internal dealFunded nonReentrant {
        (, uint256 proRataRedemptionStart, uint256 proRataRedemptionExpiry) = aelinDeal.proRataRedemption();
        (, uint256 openRedemptionStart, uint256 openRedemptionExpiry) = aelinDeal.openRedemption();

        if (block.timestamp >= proRataRedemptionStart && block.timestamp < proRataRedemptionExpiry) {
            _acceptDealTokensProRata(_recipient, _poolTokenAmount, _useMax);
        } else if (openRedemptionStart > 0 && block.timestamp < openRedemptionExpiry) {
            _acceptDealTokensOpen(_recipient, _poolTokenAmount, _useMax);
        } else {
            revert("outside of redeem window");
        }
    }

    function _acceptDealTokensProRata(address _recipient, uint256 _poolTokenAmount, bool _useMax) internal {
        uint256 maxProRata = maxProRataAmount(_recipient);
        uint256 maxAccept = maxProRata > balanceOf(_recipient) ? balanceOf(_recipient) : maxProRata;
        if (!_useMax) {
            require(
                _poolTokenAmount <= maxProRata && balanceOf(_recipient) >= _poolTokenAmount,
                "accepting more than share"
            );
        }
        uint256 acceptAmount = _useMax ? maxAccept : _poolTokenAmount;
        amountAccepted[_recipient] += acceptAmount;
        totalAmountAccepted += acceptAmount;
        _mintDealTokens(_recipient, acceptAmount);
        if (proRataConversion != 1e18 && maxProRataAmount(_recipient) == 0) {
            openPeriodEligible[_recipient] = true;
        }
    }

    function _acceptDealTokensOpen(address _recipient, uint256 _poolTokenAmount, bool _useMax) internal {
        require(openPeriodEligible[_recipient], "ineligible: didn't max pro rata");
        uint256 maxOpen = _maxOpenAvail(_recipient);
        require(maxOpen > 0, "nothing left to accept");
        uint256 acceptAmount = _useMax ? maxOpen : _poolTokenAmount;
        if (!_useMax) {
            require(acceptAmount <= maxOpen, "accepting more than share");
        }
        totalAmountAccepted += acceptAmount;
        amountAccepted[_recipient] += acceptAmount;
        _mintDealTokens(_recipient, acceptAmount);
    }

    function sponsorClaim() external {
        require(address(aelinDeal) != address(0), "no deal yet");
        (, , uint256 proRataRedemptionExpiry) = aelinDeal.proRataRedemption();
        (uint256 openRedemptionPeriod, , ) = aelinDeal.openRedemption();
        require(block.timestamp >= proRataRedemptionExpiry + openRedemptionPeriod, "still in redemption period");
        require(sponsorClaimed != true, "sponsor already claimed");
        require(totalSponsorFeeAmount > 0, "no sponsor fees");

        sponsorClaimed = true;
        aelinDeal.mintVestingToken(sponsor, totalSponsorFeeAmount);
    }

    /**
     * @dev the if statement says if you have no balance or if the deal is not funded
     * or if the pro rata period is not active, then you have 0 available for this period
     */
    function maxProRataAmount(address _purchaser) public view returns (uint256) {
        (, uint256 proRataRedemptionStart, uint256 proRataRedemptionExpiry) = aelinDeal.proRataRedemption();

        if (
            (balanceOf(_purchaser) == 0 && amountAccepted[_purchaser] == 0 && amountWithdrawn[_purchaser] == 0) ||
            holderFundingExpiry == 0 ||
            proRataRedemptionStart == 0 ||
            block.timestamp >= proRataRedemptionExpiry
        ) {
            return 0;
        }
        return
            (proRataConversion * (balanceOf(_purchaser) + amountAccepted[_purchaser] + amountWithdrawn[_purchaser])) /
            1e18 -
            amountAccepted[_purchaser];
    }

    function _maxOpenAvail(address _purchaser) internal view returns (uint256) {
        return
            balanceOf(_purchaser) + totalAmountAccepted <= purchaseTokenTotalForDeal
                ? balanceOf(_purchaser)
                : purchaseTokenTotalForDeal - totalAmountAccepted;
    }

    /**
     * @dev the holder will receive less purchase tokens than the amount
     * transferred if the purchase token burns or takes a fee during transfer
     */
    function _mintDealTokens(address _recipient, uint256 _poolTokenAmount) internal {
        _burn(_recipient, _poolTokenAmount);
        uint256 poolTokenDealFormatted = _convertPoolToDeal(_poolTokenAmount, purchaseTokenDecimals);
        uint256 aelinFeeAmt = (poolTokenDealFormatted * AELIN_FEE) / BASE;
        uint256 sponsorFeeAmt = (poolTokenDealFormatted * sponsorFee) / BASE;

        totalSponsorFeeAmount += sponsorFeeAmt;

        aelinDeal.transferProtocolFee(aelinFeeAmt);
        aelinDeal.mintVestingToken(_recipient, poolTokenDealFormatted - (sponsorFeeAmt + aelinFeeAmt));

        IERC20(purchaseToken).safeTransfer(holder, _poolTokenAmount);
        emit AcceptDeal(_recipient, address(aelinDeal), _poolTokenAmount, sponsorFeeAmt, aelinFeeAmt);
    }

    /**
     * @dev view to see how much of the deal a purchaser can accept.
     */
    function maxDealAccept(address _purchaser) external view returns (uint256) {
        /**
         * The if statement is checking to see if the holder has not funded the deal
         * or if the period is outside of a redemption window so nothing is available.
         * It then checks if you are in the pro rata period and open period eligibility
         */

        (, uint256 proRataRedemptionStart, uint256 proRataRedemptionExpiry) = aelinDeal.proRataRedemption();
        (, uint256 openRedemptionStart, uint256 openRedemptionExpiry) = aelinDeal.openRedemption();

        if (
            holderFundingExpiry == 0 ||
            proRataRedemptionStart == 0 ||
            (block.timestamp >= proRataRedemptionExpiry && openRedemptionStart == 0) ||
            (block.timestamp >= openRedemptionExpiry && openRedemptionStart != 0)
        ) {
            return 0;
        } else if (block.timestamp < proRataRedemptionExpiry) {
            uint256 maxProRata = maxProRataAmount(_purchaser);
            return maxProRata > balanceOf(_purchaser) ? balanceOf(_purchaser) : maxProRata;
        } else if (!openPeriodEligible[_purchaser]) {
            return 0;
        } else {
            return _maxOpenAvail(_purchaser);
        }
    }

    function transfer(address _dst, uint256 _amount) public virtual override transferWindow returns (bool) {
        return super.transfer(_dst, _amount);
    }

    function transferFrom(
        address _src,
        address _dst,
        uint256 _amount
    ) public virtual override transferWindow returns (bool) {
        return super.transferFrom(_src, _dst, _amount);
    }

    /**
     * @dev convert pool with varying decimals to deal tokens of 18 decimals
     * NOTE that a purchase token must not be greater than 18 decimals
     */
    function _convertPoolToDeal(uint256 _poolTokenAmount, uint256 _poolTokenDecimals) internal pure returns (uint256) {
        return _poolTokenAmount * 10 ** (18 - _poolTokenDecimals);
    }

    /**
     * @dev the sponsor may change addresses
     */
    function setSponsor(address _sponsor) external onlySponsor {
        require(_sponsor != address(0));
        futureSponsor = _sponsor;
    }

    function acceptSponsor() external {
        require(msg.sender == futureSponsor, "only future sponsor can access");
        sponsor = futureSponsor;
        emit SetSponsor(futureSponsor);
    }

    /**
     * @dev a function that any Ethereum address can call to vouch for a pool's legitimacy
     */
    function vouch() external {
        emit Vouch(msg.sender);
    }

    /**
     * @dev a function that any Ethereum address can call to disavow for a pool's legitimacy
     */
    function disavow() external {
        emit Disavow(msg.sender);
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
    modifier dealReady() {
        if (holderFundingExpiry > 0) {
            require(!aelinDeal.depositComplete() && block.timestamp >= holderFundingExpiry, "cant create new deal");
        }
        _;
    }
    modifier dealFunded() {
        require(holderFundingExpiry > 0 && aelinDeal.depositComplete(), "deal not yet funded");
        _;
    }
    modifier transferWindow() {
        (, uint256 proRataRedemptionStart, uint256 proRataRedemptionExpiry) = aelinDeal.proRataRedemption();
        (, uint256 openRedemptionStart, uint256 openRedemptionExpiry) = aelinDeal.openRedemption();

        require(
            proRataRedemptionStart == 0 ||
                (block.timestamp >= proRataRedemptionExpiry && openRedemptionStart == 0) ||
                (block.timestamp >= openRedemptionExpiry && openRedemptionStart != 0),
            "no transfers in redeem window"
        );
        _;
    }

    event SetSponsor(address indexed sponsor);
    event PurchasePoolToken(address indexed purchaser, uint256 purchaseTokenAmount);
    event WithdrawFromPool(address indexed purchaser, uint256 purchaseTokenAmount);
    event AcceptDeal(
        address indexed purchaser,
        address indexed dealAddress,
        uint256 poolTokenAmount,
        uint256 sponsorFee,
        uint256 aelinFee
    );
    event CreateDeal(string name, string symbol, address indexed sponsor, address indexed dealContract);
    event DealDetail(
        address indexed dealContract,
        address indexed underlyingDealToken,
        uint256 purchaseTokenTotalForDeal,
        uint256 underlyingDealTokenTotal,
        uint256 vestingPeriod,
        uint256 vestingCliff,
        uint256 proRataRedemptionPeriod,
        uint256 openRedemptionPeriod,
        address indexed holder,
        uint256 holderFundingDuration
    );
    event AllowlistAddress(address indexed purchaser, uint256 allowlistAmount);
    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount);
    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );
    event Vouch(address indexed voucher);
    event Disavow(address indexed voucher);
    event BlacklistNFT(address indexed collection, uint256 nftID);
}
