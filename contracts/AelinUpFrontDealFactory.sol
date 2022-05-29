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

    function createUpFrontDeal(
        UpFrontPool calldata _poolData,
        UpFrontDeal calldata _dealData,
        uint256 _underlyingDealTokenAmount
    ) external returns (address upFrontDealAddress) {
        require(_poolData.purchaseToken != address(0), "cant pass null token address");
        require(_dealData.underlyingDealToken != address(0), "cant pass null token address");
        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");

        AelinUpFrontDeal(upFrontDealAddress).initialize(_poolData, _dealData, _underlyingDealTokenAmount, msg.sender);

        emit CreateUpFrontDeal(
            upFrontDealAddress,
            string(abi.encodePacked("aeDeal-", _poolData.name)),
            string(abi.encodePacked("aeP-", _poolData.symbol)),
            _poolData.purchaseTokenCap,
            _poolData.purchaseToken,
            _poolData.sponsorFee,
            _poolData.purchaseDuration,
            msg.sender,
            _poolData.allowListAddresses.length > 0
        );
    }
}
