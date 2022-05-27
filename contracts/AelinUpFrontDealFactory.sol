// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinUpFrontDeal.sol";
import "./interfaces/IAelinUpFrontDeal.sol";

contract AelinUpFrontDealFactory is MinimalProxyFactory {
    address public immutable AELIN_TREASURY;
    address public immutable AELIN_ESCROW_LOGIC;
    address public immutable UP_FRONT_DEAL_LOGIC;

    constructor(
        address _aelinTreasury,
        address _aelinEscrow,
        address _upFrontDealLogic
    ) {
        AELIN_TREASURY = _aelinTreasury;
        AELIN_ESCROW_LOGIC = _aelinEscrow;
        UP_FRONT_DEAL_LOGIC = _upFrontDealLogic;
    }

    function createUpFrontDeal(IAelinUpFrontDeal.UpFrontDealData calldata _upFrontDealData)
        external
        returns (address poolAddress, address upFrontDealAddress)
    {
        require(_upFrontDealData.purchaseToken != address(0), "cant pass null token address");
        // require holder = msg.sender ?
        require(_upFrontDealData.holder == msg.sender, "holder must be msg.sender");
        // more requirements

        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");
        AelinUpFrontDeal aelinUpFrontDeal = AelinUpFrontDeal(upFrontDealAddress);
        aelinUpFrontDeal.initialize(
            _upFrontDealData,
            UP_FRONT_DEAL_LOGIC,
            AELIN_TREASURY,
            AELIN_ESCROW_LOGIC,
            address(this)
        );

        // events
    }
}
