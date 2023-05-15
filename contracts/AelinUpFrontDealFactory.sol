// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AelinUpFrontDeal, IAelinUpFrontDeal} from "./AelinUpFrontDeal.sol";
import {MinimalProxyFactory} from "./MinimalProxyFactory.sol";
import {AelinAllowList} from "./libraries/AelinAllowList.sol";
import {AelinNftGating} from "./libraries/AelinNftGating.sol";

contract AelinUpFrontDealFactory is MinimalProxyFactory {
    address public immutable UP_FRONT_DEAL_LOGIC;
    address public immutable AELIN_ESCROW_LOGIC;
    address public immutable AELIN_TREASURY;

    constructor(address _aelinUpFrontDeal, address _aelinEscrow, address _aelinTreasury) {
        require(_aelinUpFrontDeal != address(0), "cant pass null deal address");
        require(_aelinTreasury != address(0), "cant pass null treasury address");
        require(_aelinEscrow != address(0), "cant pass null escrow address");
        UP_FRONT_DEAL_LOGIC = _aelinUpFrontDeal;
        AELIN_ESCROW_LOGIC = _aelinEscrow;
        AELIN_TREASURY = _aelinTreasury;
    }

    function createUpFrontDeal(
        IAelinUpFrontDeal.UpFrontDealData calldata _dealData,
        IAelinUpFrontDeal.UpFrontDealConfig calldata _dealConfig,
        AelinNftGating.NftCollectionRules[] calldata _nftCollectionRules,
        AelinAllowList.InitData calldata _allowListInit
    ) external returns (address upFrontDealAddress) {
        require(_dealData.sponsor == msg.sender, "sponsor must be msg.sender");
        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");

        AelinUpFrontDeal(upFrontDealAddress).initialize(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            AELIN_TREASURY,
            AELIN_ESCROW_LOGIC
        );

        emit CreateUpFrontDeal(
            upFrontDealAddress,
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol)),
            _dealData.purchaseToken,
            _dealData.underlyingDealToken,
            _dealData.holder,
            _dealData.sponsor,
            _dealData.sponsorFee,
            _dealData.merkleRoot,
            _dealData.ipfsHash
        );

        emit CreateUpFrontDealConfig(
            upFrontDealAddress,
            _dealConfig.underlyingDealTokenTotal,
            _dealConfig.purchaseTokenPerDealToken,
            _dealConfig.purchaseRaiseMinimum,
            _dealConfig.purchaseDuration,
            _dealConfig.vestingPeriod,
            _dealConfig.vestingCliffPeriod,
            _dealConfig.allowDeallocation
        );
    }

    event CreateUpFrontDeal(
        address indexed dealAddress,
        string name,
        string symbol,
        address purchaseToken,
        address underlyingDealToken,
        address indexed holder,
        address indexed sponsor,
        uint256 sponsorFee,
        bytes32 merkleRoot,
        string ipfsHash
    );

    event CreateUpFrontDealConfig(
        address indexed dealAddress,
        uint256 underlyingDealTokenTotal,
        uint256 purchaseTokenPerDealToken,
        uint256 purchaseRaiseMinimum,
        uint256 purchaseDuration,
        uint256 vestingPeriod,
        uint256 vestingCliffPeriod,
        bool allowDeallocation
    );
}
