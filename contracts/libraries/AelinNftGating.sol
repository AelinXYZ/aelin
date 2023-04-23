// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./NftCheck.sol";

library AelinNftGating {
    uint256 constant ID_RANGES_MAX_LENGTH = 10;

    // A struct that allows specific token Id ranges to be specified in a 721 collection
    // Range is inclusive of beginning and ending token Ids
    struct IdRange {
        uint256 begin;
        uint256 end;
        // Used to specify a purchase limit for tokens in a specific ranges
        // If zero, then ignore and defer to purchaseAmount in collection Rules
        uint256 rangeAmount;
    }

    // collectionAddress should be unique, otherwise will override
    struct NftCollectionRules {
        // if 0, then unlimited purchase
        uint256 purchaseAmount;
        address collectionAddress;
        // An array of Id Ranges for gating specific nfts in unique erc721 collections (e.g. POAP)
        IdRange[] idRanges;
        // both variables below are only applicable for 1155
        uint256[] tokenIds;
        // min number of tokens required for participating
        uint256[] minTokensEligible;
    }

    struct NftGatingData {
        mapping(address => NftCollectionRules) nftCollectionDetails;
        mapping(address => mapping(uint256 => bool)) nftId;
        bool hasNftList;
    }

    struct NftPurchaseList {
        address collectionAddress;
        uint256[] tokenIds;
    }

    /**
     * @dev check if deal is nft gated, sets hasNftList
     * if yes, move collection rule array input to mapping in the data storage
     * @param _nftCollectionRules array of all nft collection rule data
     * @param _data contract storage data passed by reference
     */
    function initialize(NftCollectionRules[] calldata _nftCollectionRules, NftGatingData storage _data) external {
        if (_nftCollectionRules.length > 0) {
            // if the first address supports 721, the entire pool only supports 721
            if (NftCheck.supports721(_nftCollectionRules[0].collectionAddress)) {
                for (uint256 i; i < _nftCollectionRules.length; ++i) {
                    require(NftCheck.supports721(_nftCollectionRules[i].collectionAddress), "can only contain 721");

                    uint256 rangesLength = _nftCollectionRules[i].idRanges.length;
                    require(rangesLength <= ID_RANGES_MAX_LENGTH, "too many ranges");

                    for (uint256 j; j < rangesLength; j++) {
                        require(
                            _nftCollectionRules[i].idRanges[j].begin <= _nftCollectionRules[i].idRanges[j].end,
                            "begin greater than end"
                        );
                    }

                    _data.nftCollectionDetails[_nftCollectionRules[i].collectionAddress] = _nftCollectionRules[i];
                    emit PoolWith721(_nftCollectionRules[i].collectionAddress, _nftCollectionRules[i].purchaseAmount);
                }
                _data.hasNftList = true;
            }
            // if the first address supports 1155, the entire pool only supports 1155
            else if (NftCheck.supports1155(_nftCollectionRules[0].collectionAddress)) {
                for (uint256 i; i < _nftCollectionRules.length; ++i) {
                    require(NftCheck.supports1155(_nftCollectionRules[i].collectionAddress), "can only contain 1155");
                    require(_nftCollectionRules[i].purchaseAmount == 0, "purchase amt must be 0 for 1155");
                    _data.nftCollectionDetails[_nftCollectionRules[i].collectionAddress] = _nftCollectionRules[i];

                    for (uint256 j; j < _nftCollectionRules[i].tokenIds.length; ++j) {
                        _data.nftId[_nftCollectionRules[i].collectionAddress][_nftCollectionRules[i].tokenIds[j]] = true;
                    }
                    emit PoolWith1155(
                        _nftCollectionRules[i].collectionAddress,
                        _nftCollectionRules[i].purchaseAmount,
                        _nftCollectionRules[i].tokenIds,
                        _nftCollectionRules[i].minTokensEligible
                    );
                }
                _data.hasNftList = true;
            } else {
                require(false, "collection is not compatible");
            }
        } else {
            _data.hasNftList = false;
        }
    }

    /**
     * @dev allows anyone to become a purchaser with a qualified erc721
     * nft in the pool depending on the scenarios
     *
     * Scenarios:
     * 1. each wallet holding a qualified NFT to deposit an unlimited amount of purchase tokens
     * 2. certain amount of Investment tokens per qualified NFT held
     * @param _nftPurchaseList nft collection address and token ids to use for purchase
     * @param _data contract storage data for nft gating passed by reference
     * @param _purchaseTokenAmount amount to purchase with, must not exceed max allowable from collection rules
     * @return uint256 max purchase token amount allowable
     */
    function purchaseDealTokensWithNft(
        NftPurchaseList[] calldata _nftPurchaseList,
        NftGatingData storage _data,
        uint256 _purchaseTokenAmount
    ) external returns (uint256) {
        uint256 nftPurchaseListLength = _nftPurchaseList.length;

        require(_data.hasNftList, "pool does not have an NFT list");
        require(nftPurchaseListLength > 0, "must provide purchase list");

        //An array of arrays that correspond to the max purchase amount for each (collection, tokenId) pairing
        uint256[][] memory maxPurchaseTokenAmounts = new uint256[][](nftPurchaseListLength);

        NftPurchaseList memory nftPurchaseList;
        address collectionAddress;
        uint256[] memory tokenIds;
        uint256 tokenIdsLength;
        NftCollectionRules memory nftCollectionRules;

        //Iterate over the collections
        for (uint256 i; i < nftPurchaseListLength; ++i) {
            nftPurchaseList = _nftPurchaseList[i];
            collectionAddress = nftPurchaseList.collectionAddress;
            tokenIds = nftPurchaseList.tokenIds;
            tokenIdsLength = tokenIds.length;
            nftCollectionRules = _data.nftCollectionDetails[collectionAddress];

            //Dummy array used for this iteration of token ids
            //Must be re-declared here each loop because the length may vary
            uint256[] memory maxPurchaseTokensAmountForCollection = new uint256[](tokenIdsLength);

            require(collectionAddress != address(0), "collection should not be null");
            require(nftCollectionRules.collectionAddress == collectionAddress, "collection not in the pool");

            //Iterate over the token ids
            for (uint256 j; j < tokenIdsLength; ++j) {
                if (NftCheck.supports721(collectionAddress)) {
                    require(IERC721(collectionAddress).ownerOf(tokenIds[j]) == msg.sender, "has to be the token owner");
                    // If there are no ranges then no need to check whether token Id is within them
                    // Or whether there are any rangeAmounts
                    if (nftCollectionRules.idRanges.length > 0) {
                        //Gets a boolean for whether token Id is in range and what the range amount is if there is one
                        (bool isTokenIdInRange, uint256 rangeAmountForTokenId) = getRangeData(
                            tokenIds[j],
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

                    require(!_data.nftId[collectionAddress][tokenIds[j]], "tokenId already used");
                    _data.nftId[collectionAddress][tokenIds[j]] = true;
                    emit BlacklistNFT(collectionAddress, tokenIds[j]);
                }

                if (NftCheck.supports1155(collectionAddress)) {
                    require(_data.nftId[collectionAddress][tokenIds[j]], "tokenId not in the pool");
                    require(
                        IERC1155(collectionAddress).balanceOf(msg.sender, tokenIds[j]) >=
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
        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount greater than max allocation");

        return (maxPurchaseTokenAmount);
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

    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount);

    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );

    event BlacklistNFT(address indexed collection, uint256 nftID);
}
