// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NftCheck.sol";

library AelinNftGating {
    /**
     * @notice The maximum number of token Id ranges that an NftCollectionRules struct can have.
     */
    uint256 public constant ID_RANGES_MAX_LENGTH = 10;

    /**
     * @notice A stuct containing all the relevant information for an NFT-gated deal.
     * @dev    For ERC721 collections the nftId mapping specifies whether a token Id has been used.
     *         For ERC1155 collections, the nftId mapping specifies whether a token Id is accepted in the deal.
     */
    struct NftGatingData {
        mapping(address => NftCollectionRules) nftCollectionDetails;
        mapping(address => mapping(uint256 => bool)) nftId;
        bool hasNftList;
    }

    /**
     * @notice A struct used to specify the deal rules for an NFT-gated deal.
     * @dev    The collectionAddress should be unique, otherwise will override pre-existing storage.
     * @dev    If purchaseAmount equals zero, then unlimited purchase amounts are allowed.
     * @dev    Both the tokenIds and minTokensEligible arrays are only applicable for deals involving ERC1155
     *         collections.
     */
    struct NftCollectionRules {
        uint256 purchaseAmount;
        address collectionAddress;
        // Ranges for 721s
        IdRange[] idRanges;
        // Ids and minimums for 1155s
        uint256[] tokenIds;
        uint256[] minTokensEligible;
    }

    /**
     * @notice A struct that allows specific token Id ranges to be specified in a 721 collection.
     * @dev    The range is inclusive of beginning and ending token Ids.
     */
    struct IdRange {
        uint256 begin;
        uint256 end;
    }

    /**
     * @notice A struct used when making a purchase from an NFT-gated deal.
     */
    struct NftPurchaseList {
        address collectionAddress;
        uint256[] tokenIds;
    }

    /**
     * @notice This function helps to set up an NFT-gated deal.
     * @dev    Checks if deal is NFT-gated and sets hasNftList.
     *         If it is NFT-gated, then NftCollectionRules array is stored in the relevant NftGatingData mapping.
     * @param  _nftCollectionRules An array of all NftCollectionRules for the deal.
     * @param  _data The contract storage data where the NftCollectionRules data is stored.
     */
    function initialize(NftCollectionRules[] calldata _nftCollectionRules, NftGatingData storage _data) external {
        if (_nftCollectionRules.length > 0) {
            // If the first address supports 721, the entire pool only supports 721
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
            // If the first address supports 1155, the entire pool only supports 1155
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
     * @notice This function allows anyone to become a purchaser with a qualified ERC721 nft in the pool.
     * @dev    Multiple scenarios supported:
     *         1. Each wallet holding a qualified NFT to deposit an unlimited amount of purchase tokens.
     *         2. A certain amount of investment tokens per qualified NFT held.
     * @param  _nftPurchaseList NFT collection address and token Ids to use for purchase.
     * @param  _data Contract storage data for NFT-gating passed by reference.
     * @param  _purchaseTokenAmount Amount to purchase with, must not exceed max allowable from collection rules.
     * @return uint256 Max purchase token amount allowable.
     */
    function purchaseDealTokensWithNft(
        NftPurchaseList[] calldata _nftPurchaseList,
        NftGatingData storage _data,
        uint256 _purchaseTokenAmount
    ) external returns (uint256) {
        uint256 nftPurchaseListLength = _nftPurchaseList.length;

        require(_data.hasNftList, "pool does not have an NFT list");
        require(nftPurchaseListLength > 0, "must provide purchase list");

        NftPurchaseList memory nftPurchaseList;
        address collectionAddress;
        uint256[] memory tokenIds;
        uint256 tokenIdsLength;
        NftCollectionRules memory nftCollectionRules;

        //The running total for 721 tokens
        uint256 maxPurchaseTokenAmount;

        //Iterate over the collections
        for (uint256 i; i < nftPurchaseListLength; ++i) {
            nftPurchaseList = _nftPurchaseList[i];
            collectionAddress = nftPurchaseList.collectionAddress;
            tokenIds = nftPurchaseList.tokenIds;
            tokenIdsLength = tokenIds.length;
            nftCollectionRules = _data.nftCollectionDetails[collectionAddress];

            require(collectionAddress != address(0), "collection should not be null");
            require(nftCollectionRules.collectionAddress == collectionAddress, "collection not in the pool");

            //Iterate over the token ids
            for (uint256 j; j < tokenIdsLength; ++j) {
                if (NftCheck.supports721(collectionAddress)) {
                    require(IERC721(collectionAddress).ownerOf(tokenIds[j]) == msg.sender, "has to be the token owner");

                    // If there are no ranges then no need to check whether token Id is within them
                    if (nftCollectionRules.idRanges.length > 0) {
                        require(isTokenIdInRange(tokenIds[j], nftCollectionRules.idRanges), "tokenId not in range");
                    }

                    require(!_data.nftId[collectionAddress][tokenIds[j]], "tokenId already used");
                    _data.nftId[collectionAddress][tokenIds[j]] = true;
                    emit BlacklistNFT(collectionAddress, tokenIds[j]);
                } else {
                    //Must otherwise be an 1155 given initialise function
                    require(_data.nftId[collectionAddress][tokenIds[j]], "tokenId not in the pool");
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
                    // if there is an overflow of the previous calculation, allow the max purchase token amount
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

        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount greater than max allocation");
        return maxPurchaseTokenAmount;
    }

    function isTokenIdInRange(uint256 _tokenId, IdRange[] memory _idRanges) internal pure returns (bool) {
        for (uint256 i; i < _idRanges.length; i++) {
            if (_tokenId >= _idRanges[i].begin && _tokenId <= _idRanges[i].end) {
                return true;
            }
        }
        return false;
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
