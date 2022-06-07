// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinUpFrontDeal.sol";
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
        UP_FRONT_DEAL_LOGIC = _aelinUpFrontDeal;
        AELIN_ESCROW_LOGIC = _aelinEscrow;
        AELIN_TREASURY = _aelinTreasury;
    }

    function createUpFrontDeal(UpFrontDeal calldata _dealData, uint256 _depositUnderlayingAmount)
        external
        returns (address upFrontDealAddress)
    {
        require(_dealData.purchaseToken != address(0), "cant pass null token address");
        require(_dealData.underlyingDealToken != address(0), "cant pass null token address");
        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");

        AelinUpFrontDeal(upFrontDealAddress).initialize(
            _dealData,
            msg.sender,
            _depositUnderlayingAmount,
            UP_FRONT_DEAL_LOGIC,
            AELIN_TREASURY,
            AELIN_ESCROW_LOGIC
        );

        emit CreateUpFrontDeal(
            upFrontDealAddress,
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol)),
            _dealData.purchaseTokenCap,
            _dealData.purchaseToken,
            _dealData.sponsorFee,
            _dealData.purchaseDuration,
            _dealData.sponsor,
            _dealData.allowListAddresses.length > 0
        );
    }
}
