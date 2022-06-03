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

    UpFrontDeal public dealData;

    mapping(address => uint256) public allowList;
    mapping(address => IAelinPool.NftCollectionRules) public nftCollectionDetails;
    mapping(address => mapping(address => bool)) public nftWalletUsedForPurchase;
    mapping(address => mapping(uint256 => bool)) public nftId;
    mapping(address => uint256) public amountPurchaseTokens;
    mapping(address => uint256) public amountPoolTokens;

    uint256 public totalAmountAccepted;

    bool private hasAllowList;
    bool private hasNftList;
    bool private underlyingDepositComplete;
    bool private poolDepositComplete;

    uint256 private dealStart;
    uint256 public purchaseExpiry;
    uint256 public vestingExpiry;

    function initialize(
        UpFrontDeal calldata _dealData,
        address dealCreator,
        uint256 _depositUnderlayingAmount
    ) external {
        // pool initialization checks
        require(_dealData.purchaseDuration >= 30 minutes && _dealData.purchaseDuration <= 30 days, "not within limit");
        require(_dealData.sponsorFee <= 15e18, "exceeds max sponsor fee");
        uint8 purchaseTokenDecimals = IERC20Decimals(_dealData.purchaseToken).decimals();
        require(purchaseTokenDecimals <= 18, "purchase token not compatible");

        require(1825 days >= _dealData.vestingCliffPeriod, "max 5 year cliff");
        require(1825 days >= _dealData.vestingPeriod, "max 5 year vesting");

        require(_dealData.purchaseTokenPerDealToken > 0, "invalid deal price");
        require(
            _dealData.purchaseRaiseMinimum < _dealData.underlyingDealTokenTotal,
            "raise minimum is less than deal total"
        );

        if (_dealData.purchaseRaiseMinimum > 0 && _dealData.purchaseTokenCap > 0) {
            require(_dealData.purchaseRaiseMinimum < _dealData.purchaseTokenCap, "raise minimum is less than purchase cap");
        }

        // store pool and deal details as state variables
        dealData = _dealData;
        dealStart = block.timestamp;

        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol)),
            purchaseTokenDecimals
        );

        // Allow list logic
        // check if there's allowlist and amounts,
        // if yes, store it to `allowList` and emit a single event with the addresses and amounts
        address[] memory allowListAddresses = _dealData.allowListAddresses;
        uint256[] memory allowListAmounts = _dealData.allowListAmounts;

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
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = _dealData.nftCollectionRules;

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
        if (_depositUnderlayingAmount > 0) {
            require(
                IERC20(_dealData.underlyingDealToken).balanceOf(dealCreator) >= _depositUnderlayingAmount,
                "not enough balance"
            );
            IERC20(_dealData.underlyingDealToken).transferFrom(dealCreator, address(this), _depositUnderlayingAmount);
            uint256 currentDealTokenTotal = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
            if (currentDealTokenTotal >= _dealData.underlyingDealTokenTotal) {
                underlyingDepositComplete = true;
                purchaseExpiry = block.timestamp + dealData.purchaseDuration;
                emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry);
            }

            emit DepositDealToken(_dealData.underlyingDealToken, dealCreator, currentDealTokenTotal);
        }
    }

    /**
     * @dev method for holder to deposit underlying deal tokens
     * all underlying deal tokens must be deposited for the purchasing period to start
     * if tokens were deposited directly, this method must still be called to start the purchasing period
     */
    function depositUnderlyingTokens(uint256 _depositUnderlyingAmount) public onlyHolder {
        UpFrontDeal memory _dealData = dealData;

        require(
            IERC20(_dealData.underlyingDealToken).balanceOf(msg.sender) >= _depositUnderlyingAmount,
            "not enough balance"
        );
        require(!underlyingDepositComplete, "already deposited the total");

        uint256 balanceBeforeTransfer = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        IERC20(_dealData.underlyingDealToken).transferFrom(msg.sender, address(this), _depositUnderlyingAmount);
        uint256 balanceAfterTransfer = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        uint256 underlyingDealTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (balanceAfterTransfer >= _dealData.underlyingDealTokenTotal) {
            underlyingDepositComplete = true;
            purchaseExpiry = block.timestamp + _dealData.purchaseDuration;
            emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry);
        }

        emit DepositDealToken(_dealData.underlyingDealToken, msg.sender, underlyingDealTokenAmount);
    }

    /**
     * @dev allows holder to withdraw any excess underlying deal tokens deposited to the contract
     */
    function withdrawExcess() external onlyHolder {
        UpFrontDeal memory _dealData = dealData;
        uint256 currentBalance = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        require(currentBalance > _dealData.underlyingDealTokenTotal, "no excess to withdraw");

        uint256 excessAmount = currentBalance - _dealData.underlyingDealTokenTotal;
        IERC20(_dealData.underlyingDealToken).transferFrom(address(this), msg.sender, excessAmount);
        currentBalance = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));

        require(currentBalance == _dealData.underlyingDealTokenTotal, "incorrect balance");
        emit WithdrewExcess(address(this), excessAmount);
    }

    function acceptDeal(IAelinPool.NftPurchaseList[] calldata _nftPurchaseList, uint256 _purchaseTokenAmount) external {
        UpFrontDeal memory _dealData = dealData;
        require(underlyingDepositComplete, "deal token not yet deposited");
        require(!poolDepositComplete, "purchase token cap reached");
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(IERC20(_dealData.purchaseToken).balanceOf(msg.sender) >= _purchaseTokenAmount, "not enough purchaseToken");
        uint256 purchaseTokenAmount;

        if (_nftPurchaseList.length > 0) {
            purchaseTokenAmount = _purchaseDealTokensWithNft(_dealData, _nftPurchaseList, _purchaseTokenAmount);
        } else {
            purchaseTokenAmount = _purchaseDealTokens(_dealData, _purchaseTokenAmount);
        }

        totalAmountAccepted += purchaseTokenAmount;
        amountPurchaseTokens[msg.sender] += purchaseTokenAmount;

        uint256 poolTokenAmount = purchaseTokenAmount / _dealData.purchaseTokenPerDealToken;
        amountPoolTokens[msg.sender] += poolTokenAmount;

        emit AcceptDeal(
            msg.sender,
            purchaseTokenAmount,
            amountPurchaseTokens[msg.sender],
            poolTokenAmount,
            amountPoolTokens[msg.sender]
        );
    }

    /**
     * @dev purchase deal tokens, if purchase cap is reached allow user to purchase up to the max
     * @return uint256 purchase token quantity
     */
    function _purchaseDealTokens(UpFrontDeal memory _dealData, uint256 _purchaseTokenAmount) internal returns (uint256) {
        if (hasAllowList) {
            require(_purchaseTokenAmount <= allowList[msg.sender], "more than allocation");
            allowList[msg.sender] -= _purchaseTokenAmount;
        }

        uint256 balanceBeforeTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        IERC20(_dealData.purchaseToken).transferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (_dealData.purchaseTokenCap > 0) {
            require(balanceAfterTransfer <= _dealData.purchaseTokenCap, "deposit exceeded cap");
            if (balanceAfterTransfer == _dealData.purchaseTokenCap) {
                poolDepositComplete = true;
            }
        }

        return (purchaseTokenAmount);
    }

    function _purchaseDealTokensWithNft(
        UpFrontDeal memory _dealData,
        IAelinPool.NftPurchaseList[] calldata _nftPurchaseList,
        uint256 _purchaseTokenAmount
    ) internal returns (uint256) {
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

        uint256 balanceBeforeTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        IERC20(_dealData.purchaseToken).transferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (_dealData.purchaseTokenCap > 0) {
            require(balanceAfterTransfer <= _dealData.purchaseTokenCap, "deposit exceeded cap");
            if (balanceAfterTransfer == _dealData.purchaseTokenCap) {
                poolDepositComplete = true;
            }
        }

        return (purchaseTokenAmount);
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

    modifier onlyHolder() {
        require(msg.sender == dealData.holder);
        _;
    }

    event DealFullyFunded(address upFrontDealAddress, uint256 timestamp, uint256 purchaseExpiryTimestamp);
    event WithdrewExcess(address UpFrontDealAddress, uint256 amountWithdrawn);
    event AcceptDeal(
        address indexed purchaser,
        uint256 amountPurchased,
        uint256 totalPurchased,
        uint256 amountDealTokens,
        uint256 totalDealTokens
    );
}
