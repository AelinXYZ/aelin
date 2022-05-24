// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinDeal.sol";
import "./AelinUpFrontDealFactory.sol";
import "./interfaces/IAelinDeal.sol";

contract AelinUpFrontDeal is MinimalProxyFactory, IAelinDeal, AelinDeal {
    // AelinPool public aelinPoolAddress;
    // AelinDeal public aelinDealAddress;

    constructor() AelinDeal() {}

    function initializeUpFrontDeal(
        string calldata _name,
        string calldata _symbol,
        DealData calldata _dealData,
        uint256 _underlyingDealTokenAmount,
        address upFrontFactory
    ) public {
        initialize(
            _name,
            _symbol,
            _dealData,
            AelinUpFrontDealFactory(upFrontFactory).AELIN_TREASURY(),
            AelinUpFrontDealFactory(upFrontFactory).AELIN_ESCROW_LOGIC()
        );
        // additional checks required
        if (_underlyingDealTokenAmount > 0) {
            // (bool success, bytes memory returndata) = address(aelinDealAddress).delegatecall(
            //     abi.encodeWithSelector(AelinDeal.depositUnderlying.selector, _underlyingDealTokenAmount)
            // );
            depositUnderlying(_underlyingDealTokenAmount);
        }
    }
}
