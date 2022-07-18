// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinUpFrontDeal.sol";
import "./libraries/AelinNftGating.sol";
import "./libraries/AelinAllowList.sol";
import {IAelinUpFrontDeal} from "./interfaces/IAelinUpFrontDeal.sol";

contract AelinUpFrontDealFactory is MinimalProxyFactory, IAelinUpFrontDeal {
    address public immutable UP_FRONT_DEAL_LOGIC;
    address public immutable AELIN_ESCROW_LOGIC;
    address public immutable AELIN_TREASURY;

    constructor(
        address _aelinUpFrontDeal,
        address _aelinEscrow,
        address _aelinTreasury
    ) {
        require(_aelinUpFrontDeal != address(0), "cant pass null deal address");
        require(_aelinTreasury != address(0), "cant pass null treasury address");
        require(_aelinEscrow != address(0), "cant pass null escrow address");
        UP_FRONT_DEAL_LOGIC = _aelinUpFrontDeal;
        AELIN_ESCROW_LOGIC = _aelinEscrow;
        AELIN_TREASURY = _aelinTreasury;
    }

    function createUpFrontDeal(
        UpFrontDealData calldata _dealData,
        UpFrontDealConfig calldata _dealConfig,
        AelinNftGating.NftCollectionRules[] calldata _nftCollectionRules,
        AelinAllowList.InitData calldata _allowListInit,
        uint256 _depositUnderlyingAmount
    ) external returns (address upFrontDealAddress) {
        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");

        if (_depositUnderlyingAmount > 0) {
            require(
                IERC20(_dealData.underlyingDealToken).balanceOf(msg.sender) >= _depositUnderlyingAmount,
                "not enough balance"
            );
            uint256 _balanceBeforeTransfer = ERC20(_dealData.underlyingDealToken).balanceOf(address(this));
            IERC20(_dealData.underlyingDealToken).transferFrom(msg.sender, address(this), _depositUnderlyingAmount);
            uint256 _balanceAfterTransfer = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
            _depositUnderlyingAmount = _balanceAfterTransfer - _balanceBeforeTransfer;
            IERC20(_dealData.underlyingDealToken).transfer(upFrontDealAddress, _depositUnderlyingAmount);
        }

        AelinUpFrontDeal(upFrontDealAddress).initialize(
            _dealData,
            _dealConfig,
            _nftCollectionRules,
            _allowListInit,
            msg.sender,
            AELIN_TREASURY,
            AELIN_ESCROW_LOGIC
        );

        emit CreateUpFrontDeal(
            upFrontDealAddress,
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol)),
            _dealData.purchaseToken,
            _dealData.underlyingDealToken,
            _dealData.sponsor,
            _dealData.holder,
            _dealData.sponsorFee
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
}
