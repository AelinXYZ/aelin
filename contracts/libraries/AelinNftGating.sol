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
        require(_data.hasNftList, "pool does not have an NFT list");
        require(_nftPurchaseList.length > 0, "must provide purchase list");

        uint256 maxPurchaseTokenAmount;

        for (uint256 i; i < _nftPurchaseList.length; ++i) {
            NftPurchaseList memory nftPurchaseList = _nftPurchaseList[i];
            address _collectionAddress = nftPurchaseList.collectionAddress;
            uint256[] memory _tokenIds = nftPurchaseList.tokenIds;

            NftCollectionRules memory nftCollectionRules = _data.nftCollectionDetails[_collectionAddress];

            require(_collectionAddress != address(0), "collection should not be null");
            require(nftCollectionRules.collectionAddress == _collectionAddress, "collection not in the pool");

            if (nftCollectionRules.purchaseAmount > 0) {
                if (NftCheck.supports721(_collectionAddress)) {
                    unchecked {
                        uint256 collectionAllowance = nftCollectionRules.purchaseAmount * _tokenIds.length;
                        // if there is an overflow of the pervious calculation, allow the max purchase token amount
                        if (collectionAllowance / nftCollectionRules.purchaseAmount != _tokenIds.length) {
                            maxPurchaseTokenAmount = type(uint256).max;
                        } else {
                            maxPurchaseTokenAmount += collectionAllowance;
                            if (maxPurchaseTokenAmount < collectionAllowance) {
                                maxPurchaseTokenAmount = type(uint256).max;
                            }
                        }
                    }
                }
            }

            if (nftCollectionRules.purchaseAmount == 0) {
                maxPurchaseTokenAmount = type(uint256).max;
            }

            if (NftCheck.supports721(_collectionAddress)) {
                for (uint256 j; j < _tokenIds.length; ++j) {
                    require(IERC721(_collectionAddress).ownerOf(_tokenIds[j]) == msg.sender, "has to be the token owner");
                    //If there are no ranges then no need to check whether token Id is within them
                    if (nftCollectionRules.idRanges.length > 0) {
                        require(isTokenIdInRange(_tokenIds[j], nftCollectionRules.idRanges), "tokenId not in range");
                    }
                    require(!_data.nftId[_collectionAddress][_tokenIds[j]], "tokenId already used");
                    _data.nftId[_collectionAddress][_tokenIds[j]] = true;
                    emit BlacklistNFT(_collectionAddress, _tokenIds[j]);
                }
            }
            if (NftCheck.supports1155(_collectionAddress)) {
                for (uint256 j; j < _tokenIds.length; ++j) {
                    require(_data.nftId[_collectionAddress][_tokenIds[j]], "tokenId not in the pool");
                    require(
                        IERC1155(_collectionAddress).balanceOf(msg.sender, _tokenIds[j]) >=
                            nftCollectionRules.minTokensEligible[j],
                        "erc1155 balance too low"
                    );
                }
            }
        }

        require(_purchaseTokenAmount <= maxPurchaseTokenAmount, "purchase amount greater than max allocation");

        return (maxPurchaseTokenAmount);
    }

    //Used to test whether a token Id is in a collection Rule set of ranges
    //Perhaps make this public if it's useful elsewhere?
    function isTokenIdInRange(uint256 _tokenId, IdRange[] memory idRanges) internal pure returns (bool) {
        for (uint256 i; i < idRanges.length; i++) {
            if (_tokenId >= idRanges[i].begin && _tokenId <= idRanges[i].end) {
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
