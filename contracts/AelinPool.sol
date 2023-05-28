// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AelinDeal, IAelinDeal} from "./AelinDeal.sol";
import {AelinERC20} from "./AelinERC20.sol";
import {MinimalProxyFactory} from "./MinimalProxyFactory.sol";
import {IAelinPool} from "./interfaces/IAelinPool.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";
import {NftCheck, IERC721, IERC1155} from "./libraries/NftCheck.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AelinPool is AelinERC20, MinimalProxyFactory, IAelinPool, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant BASE = 100 * 10 ** 18;
    uint256 public constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 public constant AELIN_FEE = 2 * 10 ** 18;
    uint256 public constant ID_RANGES_MAX_LENGTH = 10;
    uint8 public constant MAX_DEALS = 5;

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
    // CollectionAddress -> NftCollectionRules struct
    mapping(address => NftCollectionRules) public nftCollectionDetails;

    /**
     * @dev For 721, it is used for blacklisting the tokenId of a collection and for 1155, it is used
     * for identifying the eligible tokenIds for participating in the pool.
     */
    mapping(address => mapping(uint256 => bool)) public nftId;
    bool public hasNftList;
    bool public hasAllowList;

    string private storedName;
    string private storedSymbol;

    /**
     * @dev The initialize method replaces the constructor setup and can only be called once.
     *
     * Requirements:
     * - Max 1 year duration.
     * - Purchase expiry can be set from 30 minutes to 30 days.
     * - Max sponsor fee is 15000 representing 15%.
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
        purchaseTokenDecimals = IERC20Extended(_poolData.purchaseToken).decimals();
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
            require(allowListAddresses.length == allowListAmounts.length, "arrays should be same length");
            for (uint256 i; i < allowListAddresses.length; ++i) {
                allowList[allowListAddresses[i]] = allowListAmounts[i];
                emit AllowlistAddress(allowListAddresses[i], allowListAmounts[i]);
            }
            hasAllowList = true;
        }

        NftCollectionRules[] calldata nftCollectionRules = _poolData.nftCollectionRules;

        if (nftCollectionRules.length > 0) {
            // If the first address supports 721, the entire pool only supports 721
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
            // If the first address supports 1155, the entire pool only supports 1155
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
     * @notice This function allows anyone to become a purchaser by sending purchase tokens in exchange
     * for pool tokens.
     * @param _purchaseTokenAmount The amount of purchase tokens a user will send to the pool.
     * NOTE The deal must be within the purchase expiry window, and the cap must not have been exceeded.
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
     * @notice This function allows anyone to become a purchaser with a qualified ERC721 token in the
     * pool depending on two scenarios. Either, each account holding a qualified NFT can deposit an
     * unlimited amount of purchase tokens, or there exists a certain amount of investment tokens per
     * qualified NFT held.
     * @param _nftPurchaseList The list of NFTs used to qualify an account for purchasing pool tokens.
     * @param _purchaseTokenAmount The amount of purchase tokens a user will send to the pool.
     */
    function purchasePoolTokensWithNft(
        NftPurchaseList[] calldata _nftPurchaseList,
        uint256 _purchaseTokenAmount
    ) external nonReentrant {
        uint256 nftPurchaseListLength = _nftPurchaseList.length;

        require(hasNftList, "pool does not have an NFT list");
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(nftPurchaseListLength > 0, "must provide purchase list");

        NftPurchaseList memory nftPurchaseList;
        address collectionAddress;
        uint256[] memory tokenIds;
        uint256 tokenIdsLength;
        NftCollectionRules memory nftCollectionRules;

        // The running total for 721 tokens
        uint256 maxPurchaseTokenAmount;

        // Iterate over the collections
        for (uint256 i; i < nftPurchaseListLength; ++i) {
            nftPurchaseList = _nftPurchaseList[i];
            collectionAddress = nftPurchaseList.collectionAddress;
            tokenIds = nftPurchaseList.tokenIds;
            tokenIdsLength = tokenIds.length;
            nftCollectionRules = nftCollectionDetails[collectionAddress];

            require(collectionAddress != address(0), "collection should not be null");
            require(nftCollectionRules.collectionAddress == collectionAddress, "collection not in the pool");

            // Iterate over the token ids
            for (uint256 j; j < tokenIdsLength; ++j) {
                if (NftCheck.supports721(collectionAddress)) {
                    require(IERC721(collectionAddress).ownerOf(tokenIds[j]) == msg.sender, "has to be the token owner");

                    // If there are no ranges then no need to check whether token Id is within them
                    if (nftCollectionRules.idRanges.length > 0) {
                        require(isTokenIdInRange(tokenIds[j], nftCollectionRules.idRanges), "tokenId not in range");
                    }

                    require(!nftId[collectionAddress][tokenIds[j]], "tokenId already used");
                    nftId[collectionAddress][tokenIds[j]] = true;
                    emit BlacklistNFT(collectionAddress, tokenIds[j]);
                } else {
                    // Must otherwise be an 1155 given initialise function
                    require(nftId[collectionAddress][tokenIds[j]], "tokenId not in the pool");
                    require(
                        IERC1155(collectionAddress).balanceOf(msg.sender, tokenIds[j]) >=
                            nftCollectionRules.minTokensEligible[j],
                        "erc1155 balance too low"
                    );
                }
            }

            if (nftCollectionRules.purchaseAmount > 0 && maxPurchaseTokenAmount != type(uint256).max) {
                unchecked {
                    uint256 collectionAllowance = nftCollectionRules.purchaseAmount * tokenIdsLength;
                    // If there is an overflow of the previous calculation, allow the max purchase token amount
                    if (collectionAllowance / nftCollectionRules.purchaseAmount != tokenIdsLength) {
                        maxPurchaseTokenAmount = type(uint256).max;
                    } else {
                        maxPurchaseTokenAmount += collectionAllowance;
                        if (maxPurchaseTokenAmount < collectionAllowance) {
                            maxPurchaseTokenAmount = type(uint256).max;
                        }
                    }
                }
            }

            if (nftCollectionRules.purchaseAmount == 0) {
                maxPurchaseTokenAmount = type(uint256).max;
            }
        }

        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount greater than max");

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

    function isTokenIdInRange(uint256 _tokenId, IdRange[] memory _idRanges) internal pure returns (bool) {
        for (uint256 i; i < _idRanges.length; i++) {
            if (_tokenId >= _idRanges[i].begin && _tokenId <= _idRanges[i].end) {
                return true;
            }
        }
        return false;
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
     * @notice This function allows any purchaser to take all of their purchase tokens back in exchange
     * for pool tokens if they do not accept a deal.
     * NOTE The pool must have expired either due to the creation of a deal or the end of the duration.
     */
    function withdrawMaxFromPool() external {
        _withdraw(balanceOf(msg.sender));
    }

    /**
     * @notice This function allows any purchaser to a portion of their purchase tokens back in exchange
     * for pool tokens if they do not accept a deal.
     * @param _purchaseTokenAmount The amount of purchase tokens the user wishes to recieve.
     * NOTE The pool must have expired either due to the creation of a deal or the end of the duration.
     */
    function withdrawFromPool(uint256 _purchaseTokenAmount) external {
        _withdraw(_purchaseTokenAmount);
    }

    /**
     * @dev Purchasers can withdraw at the end of the pool expiry period if no deal was presented or they
     * can withdraw after the holder funding period if they do not like a deal.
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
     * @notice This function allows the sponsor to create a deal.
     * @param _underlyingDealToken The address of the underlying deal token.
     * @param _purchaseTokenTotalForDeal The total amount of purchase tokens to be distributed for the
     * deal.
     * @param _underlyingDealTokenTotal The total amount of underlying deal tokens to be used in the deal.
     * @param _vestingPeriod The vesting period for the deal.
     * @param _vestingCliffPeriod The vesting cliff period for the deal.
     * @param _proRataRedemptionPeriod The pro rata redemption period for the deal.
     * @param _openRedemptionPeriod The open redemption period for the deal.
     * @param _holder The account with the holder role for the deal.
     * @param _holderFundingDuration The holder funding duration for the deal.
     * @return address The address of the storage proxy contract for the newly created deal.
     * NOTE The deal must be fully funded with the underlying deal token before a purchaser may accept
     * the deal. If the deal has not been funded before the expiry period is over then the sponsor may
     * create a new deal for the pool of capital by calling this function again. Moreover, the following
     * requirements must be satisfied:
     * - The purchase expiry period must be over.
     * - The vestingPeriod must be less than 5 years.
     * - The vestingCliffPeriod must be less than 5 years.
     * - The holder funding expiry period must be from 30 minutes to 30 days.
     * - The pro rata redemption period must be from 30 minutes to 30 days.
     * - The purchase token total for the deal that may be accepted must be <= the funds in the pool.
     * - If the pro rata conversion ratio (purchase token total for the deal:funds in pool) is 1:1 then
     *   the open redemption period must be 0, otherwise the open period is from 30 minutes to 30 days.
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
     * @notice This function allows a purchaser to exchange all of their pool tokens for deal tokens.
     * NOTE The redemption period must be either in the pro rata or open periods, the purchaser cannot
     * accept more than their share for a period, and if participating in the open period, a purchaser
     * must have maxxed out their contribution in the pro rata phase.
     */
    function acceptMaxDealTokens() external {
        _acceptDealTokens(msg.sender, 0, true);
    }

    /**
     * @notice This function allows a purchaser to exchange a portion of their pool tokens for deal
     * tokens.
     * @param _poolTokenAmount The amount of pool tokens to be exchanged.
     * NOTE The redemption period must be either in the pro rata or open periods, the purchaser cannot
     * accept more than their share for a period, and if participating in the open period, a purchaser
     * must have maxxed out their contribution in the pro rata phase.
     */
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

    /**
     * @notice This function allows the sponsor to claim their sponsor fee amount.
     * NOTE The redemption period must have expired.
     */
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
     * @notice This view function returns the maximum pro rata amount a purchaser can receive at any
     * given time.
     * @param _purchaser The purchaser's address.
     * @return uint256 The max pro rata amount the purchaser can recieve.
     * @dev The if statement says if you have no balance or if the deal is not funded or if the pro rata
     * period is not active, then you have 0 available for this period.
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
     * @dev The holder will receive less purchase tokens than the amount transferred if the purchase token
     * burns or takes a fee during transfer.
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
     * @notice This view function returns the maximum amount of deal tokens a purchaser can recieve.
     * @param _purchaser The purchaser's address.
     * @return uint256 The max amount the purchaser can recieve.
     */
    function maxDealAccept(address _purchaser) external view returns (uint256) {
        /**
         * @dev The if statement is checking to see if the holder has not funded the deal or if the
         * period is outside of a redemption window so nothing is available. It then checks if you are
         * in the pro rata period and open period eligibility.
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
     * @dev Convert pool with varying decimals to deal tokens of 18 decimals.
     * NOTE A purchase token must not be greater than 18 decimals.
     */
    function _convertPoolToDeal(uint256 _poolTokenAmount, uint256 _poolTokenDecimals) internal pure returns (uint256) {
        return _poolTokenAmount * 10 ** (18 - _poolTokenDecimals);
    }

    /**
     * @notice This function allows the sponosor to set a future sponsor address without changing the
     * sponsor address currently.
     * @param _futureSponsor The future sponsor address.
     */
    function setSponsor(address _futureSponsor) external onlySponsor {
        require(_futureSponsor != address(0), "cant pass null sponsor address");
        futureSponsor = _futureSponsor;
    }

    /**
     * @notice This function allows the future sponsor address to replace the current sponsor address.
     */
    function acceptSponsor() external {
        require(msg.sender == futureSponsor, "only future sponsor can access");
        sponsor = futureSponsor;
        emit SetSponsor(futureSponsor);
    }

    /**
     * @notice A function that any address can call to vouch for a pool's legitimacy.
     */
    function vouch() external {
        emit Vouch(msg.sender);
    }

    /**
     * @notice A function that any address can call to disavow a pool's legitimacy.
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
