// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import {AelinDeal} from "./AelinDeal.sol";
import {AelinPool} from "./AelinPool.sol";
import {IAelinPool} from "./interfaces/IAelinPool.sol";
import {IAelinUpFrontDeal} from "./interfaces/IAelinUpFrontDeal.sol";
import "./libraries/NftCheck.sol";
import "./interfaces/ICryptoPunks.sol";

contract AelinUpFrontDeal is AelinERC20, IAelinUpFrontDeal {
    address constant CRYPTO_PUNKS = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    UpFrontPool public poolData;
    UpFrontDeal public dealData;

    mapping(address => uint256) public allowList;
    mapping(address => IAelinPool.NftCollectionRules) public nftCollectionDetails;
    mapping(address => mapping(address => bool)) public nftWalletUsedForPurchase;
    mapping(address => mapping(uint256 => bool)) public nftId;
    mapping(address => uint256) public amountAccepted;

    uint256 public totalAmountAccepted;
    uint256 public currentDealTokenTotal;
    uint256 private poolStart;

    bool private hasAllowList;
    bool private hasNftList;
    bool private dealDepositComplete;
    bool public poolDepositComplete;

    function initialize(
        UpFrontPool calldata _poolData,
        UpFrontDeal calldata _dealData,
        uint256 _underlyingDealTokenAmount,
        address _sponsor
    ) external {
        // pool initialization checks
        require(_poolData.purchaseDuration >= 30 minutes && _poolData.purchaseDuration <= 30 days, "not within limit");
        require(_poolData.sponsorFee <= 15e18, "exceeds max sponsor fee");
        uint8 purchaseTokenDecimals = IERC20Decimals(_poolData.purchaseToken).decimals();
        require(purchaseTokenDecimals <= 18, "purchase token not compatible");

        // deal initialization checks
        require(
            _dealData.proRataRedemptionPeriod >= 30 minutes && _dealData.proRataRedemptionPeriod <= 30 days,
            "30 mins - 30 days for prorata"
        );
        require(1825 days >= _dealData.vestingCliffPeriod, "max 5 year cliff");
        require(1825 days >= _dealData.vestingPeriod, "max 5 year vesting");

        // store pool and deal details as state variables
        poolData = _poolData;
        dealData = _dealData;
        poolStart = block.timestamp;

        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aePool-", _poolData.name)),
            string(abi.encodePacked("aeP-", _poolData.symbol)),
            purchaseTokenDecimals
        );

        // Allow list logic
        // check if there's allowlist and amounts,
        // if yes, store it to `allowList` and emit a single event with the addresses and amounts
        address[] memory allowListAddresses = _poolData.allowListAddresses;
        uint256[] memory allowListAmounts = _poolData.allowListAmounts;

        if (allowListAddresses.length > 0 || allowListAmounts.length > 0) {
            require(
                allowListAddresses.length == allowListAmounts.length,
                "allowListAddresses and allowListAmounts arrays should have the same length"
            );
            for (uint256 i = 0; i < allowListAddresses.length; i++) {
                allowList[allowListAddresses[i]] = allowListAmounts[i];
            }
            hasAllowList = true;
            emit AllowlistAddress(allowListAddresses, allowListAmounts);
        }

        // NftCollection logic
        // check if the deal is nft gated
        // if yes, store it in `nftCollectionDetails` and `nftId` and emit respective events for 721 and 1155
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = _poolData.nftCollectionRules;

        if (nftCollectionRules.length > 0) {
            // if the first address supports punks or 721, the entire pool only supports 721 or punks
            if (
                nftCollectionRules[0].collectionAddress == CRYPTO_PUNKS ||
                NftCheck.supports721(nftCollectionRules[0].collectionAddress)
            ) {
                for (uint256 i = 0; i < nftCollectionRules.length; i++) {
                    require(
                        nftCollectionRules[i].collectionAddress == CRYPTO_PUNKS ||
                            NftCheck.supports721(nftCollectionRules[i].collectionAddress),
                        "can only contain 721"
                    );
                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];
                    emit PoolWith721(
                        nftCollectionRules[i].collectionAddress,
                        nftCollectionRules[i].purchaseAmount,
                        nftCollectionRules[i].purchaseAmountPerToken
                    );
                }
                hasNftList = true;
            }
            // if the first address supports 1155, the entire pool only supports 1155
            else if (NftCheck.supports1155(nftCollectionRules[0].collectionAddress)) {
                for (uint256 i = 0; i < nftCollectionRules.length; i++) {
                    require(NftCheck.supports1155(nftCollectionRules[i].collectionAddress), "can only contain 1155");
                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];

                    for (uint256 j = 0; j < nftCollectionRules[i].tokenIds.length; j++) {
                        nftId[nftCollectionRules[i].collectionAddress][nftCollectionRules[i].tokenIds[j]] = true;
                    }
                    emit PoolWith1155(
                        nftCollectionRules[i].collectionAddress,
                        nftCollectionRules[i].purchaseAmount,
                        nftCollectionRules[i].purchaseAmountPerToken,
                        nftCollectionRules[i].tokenIds,
                        nftCollectionRules[i].minTokensEligible
                    );
                }
                hasNftList = true;
            } else {
                revert("collection is not compatible");
            }
        }

        // deposit underlying token logic
        // check if the underlyingDealAmount is more than 0,
        // if yes, transfer it to this contract and store it in `currentDealTokenTotal` and add it
        if (_underlyingDealTokenAmount > 0) {
            currentDealTokenTotal += _underlyingDealTokenAmount;
            IERC20(_dealData.underlyingDealToken).transferFrom(_sponsor, address(this), _underlyingDealTokenAmount);
            if (_underlyingDealTokenAmount >= _dealData.underlyingDealTokenTotal) {
                dealDepositComplete = true;
                emit DealFullyFunded(address(this), block.timestamp, block.timestamp + _dealData.proRataRedemptionPeriod);
            } else {
                emit DepositDealToken(_dealData.underlyingDealToken, _sponsor, _underlyingDealTokenAmount);
            }
        }
    }

    function depositDealTokens(uint256 _underlyingDealTokenAmount) public {
        UpFrontDeal memory _dealData = dealData;
        uint256 _currentDealTokenTotal = currentDealTokenTotal;

        require(
            IERC20(_dealData.underlyingDealToken).balanceOf(msg.sender) >= _underlyingDealTokenAmount,
            "not enough balance"
        );
        require(_currentDealTokenTotal < _dealData.maxDealTotalSupply, "already deposited the total");

        IERC20(_dealData.underlyingDealToken).transferFrom(msg.sender, address(this), _underlyingDealTokenAmount);

        if (_underlyingDealTokenAmount + _currentDealTokenTotal < _dealData.maxDealTotalSupply) {
            currentDealTokenTotal += _underlyingDealTokenAmount;
            emit DepositDealToken(_dealData.underlyingDealToken, msg.sender, _underlyingDealTokenAmount);
        }

        if (_underlyingDealTokenAmount + _currentDealTokenTotal >= _dealData.maxDealTotalSupply) {
            dealDepositComplete = true;
            emit DealFullyFunded(address(this), block.timestamp, block.timestamp + _dealData.proRataRedemptionPeriod);
        }
    }

    function purchasePoolAndAccept(IAelinPool.NftPurchaseList[] calldata _nftPurchaseList, uint256 _purchaseTokenAmount)
        external
    {
        UpFrontPool memory _poolData = poolData;
        require(block.timestamp < poolStart + _poolData.purchaseDuration, "not in purchase window");
        require(dealDepositComplete, "deal token not yet deposited");
        require(!poolDepositComplete, "pool completed");
        require(IERC20(_poolData.purchaseToken).balanceOf(msg.sender) >= _purchaseTokenAmount, "not enough purchaseToken");

        if (_nftPurchaseList.length > 0) {
            _purchasePoolTokensWithNft(_poolData, _nftPurchaseList, _purchaseTokenAmount);
        } else {
            _purchasePoolTokens(_poolData, _purchaseTokenAmount);
        }

        totalAmountAccepted += _purchaseTokenAmount;
        amountAccepted[msg.sender] += _purchaseTokenAmount;
    }

    function _purchasePoolTokens(UpFrontPool memory _poolData, uint256 _purchaseTokenAmount) internal {
        if (hasAllowList) {
            require(_purchaseTokenAmount <= allowList[msg.sender], "more than allocation");
            allowList[msg.sender] -= _purchaseTokenAmount;
        }

        uint256 currentBalance = IERC20(_poolData.purchaseToken).balanceOf(address(this));
        IERC20(_poolData.purchaseToken).transferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(_poolData.purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = balanceAfterTransfer - currentBalance;

        if (_poolData.purchaseTokenCap > 0) {
            uint256 totalPoolAfter = totalSupply() + purchaseTokenAmount;
            require(totalPoolAfter <= _poolData.purchaseTokenCap, "cap has been exceeded");
            if (totalPoolAfter == _poolData.purchaseTokenCap) {
                poolDepositComplete = true;
            }
        }

        _mint(msg.sender, purchaseTokenAmount);
    }

    function _purchasePoolTokensWithNft(
        UpFrontPool memory _poolData,
        IAelinPool.NftPurchaseList[] calldata _nftPurchaseList,
        uint256 _purchaseTokenAmount
    ) internal {
        require(hasNftList, "pool does not have an NFT list");

        uint256 maxPurchaseTokenAmount;

        for (uint256 i = 0; i < _nftPurchaseList.length; i++) {
            IAelinPool.NftPurchaseList memory nftPurchaseList = _nftPurchaseList[i];
            address _collectionAddress = nftPurchaseList.collectionAddress;
            uint256[] memory _tokenIds = nftPurchaseList.tokenIds;

            IAelinPool.NftCollectionRules memory nftCollectionRules = nftCollectionDetails[_collectionAddress];
            require(nftCollectionRules.collectionAddress == _collectionAddress, "collection not in the pool");

            if (nftCollectionRules.purchaseAmountPerToken) {
                maxPurchaseTokenAmount += nftCollectionRules.purchaseAmount * _tokenIds.length;
            }

            if (!nftCollectionRules.purchaseAmountPerToken && nftCollectionRules.purchaseAmount > 0) {
                require(!nftWalletUsedForPurchase[_collectionAddress][msg.sender], "wallet already used for nft set");
                nftWalletUsedForPurchase[_collectionAddress][msg.sender] = true;
                maxPurchaseTokenAmount += nftCollectionRules.purchaseAmount;
            }

            if (nftCollectionRules.purchaseAmount == 0) {
                maxPurchaseTokenAmount = _purchaseTokenAmount;
            }

            if (NftCheck.supports721(_collectionAddress)) {
                _blackListCheck721(_collectionAddress, _tokenIds);
            }
            if (NftCheck.supports1155(_collectionAddress)) {
                _eligibilityCheck1155(_collectionAddress, _tokenIds, nftCollectionRules);
            }
            if (_collectionAddress == CRYPTO_PUNKS) {
                _blackListCheckPunks(_collectionAddress, _tokenIds);
            }
        }

        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount should be less the max allocation");

        uint256 amountBefore = IERC20(_poolData.purchaseToken).balanceOf(address(this));
        IERC20(_poolData.purchaseToken).transferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 amountAfter = IERC20(_poolData.purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = amountAfter - amountBefore;

        if (_poolData.purchaseTokenCap > 0) {
            uint256 totalPoolAfter = totalSupply() + purchaseTokenAmount;
            require(totalPoolAfter <= _poolData.purchaseTokenCap, "cap has been exceeded");
            if (totalPoolAfter == _poolData.purchaseTokenCap) {
                poolDepositComplete = true;
            }
        }

        _mint(msg.sender, purchaseTokenAmount);
    }

    function _blackListCheck721(address _collectionAddress, uint256[] memory _tokenIds) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(IERC721(_collectionAddress).ownerOf(_tokenIds[i]) == msg.sender, "has to be the token owner");
            require(!nftId[_collectionAddress][_tokenIds[i]], "tokenId already used");
            nftId[_collectionAddress][_tokenIds[i]] = true;
        }
    }

    function _eligibilityCheck1155(
        address _collectionAddress,
        uint256[] memory _tokenIds,
        IAelinPool.NftCollectionRules memory nftCollectionRules
    ) internal view {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(nftId[_collectionAddress][_tokenIds[i]], "tokenId not in the pool");
            require(
                IERC1155(_collectionAddress).balanceOf(msg.sender, _tokenIds[i]) >= nftCollectionRules.minTokensEligible[i],
                "erc1155 balance too low"
            );
        }
    }

    function _blackListCheckPunks(address _punksAddress, uint256[] memory _tokenIds) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(ICryptoPunks(_punksAddress).punkIndexToAddress(_tokenIds[i]) == msg.sender, "not the owner");
            require(!nftId[_punksAddress][_tokenIds[i]], "tokenId already used");
            nftId[_punksAddress][_tokenIds[i]] = true;
        }
    }
}
