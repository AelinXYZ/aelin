// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

contract AelinPoolFactory is MinimalProxyFactory {
    constructor() {}

    function createPool(
        string memory _name,
        string memory _symbol,
        uint _purchaseTokenCap,
        address _purchaseToken,
        uint _duration,
        uint _sponsorFee,
        uint _purchaseExpiry,
        address _aelinPoolLogicAddress,
        address _aelinDealLogicAddress
    ) external returns (address) {
        AelinPool aelin_pool = AelinPool(_cloneAsMinimalProxy(_aelinPoolLogicAddress, "Could not create new deal"));
        aelin_pool.initialize(
            _name,
            _symbol,
            _purchaseTokenCap,
            _purchaseToken,
            _duration,
            _sponsorFee,
            msg.sender,
            _purchaseExpiry,
            _aelinDealLogicAddress
        );

        emit CreatePool(
            address(aelin_pool),
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol)),
            _purchaseTokenCap,
            _purchaseToken,
            _duration,
            _sponsorFee,
            msg.sender,
            _purchaseExpiry
        );

        return address(aelin_pool);
    }

    // TODO consider adding versioning to events
    event CreatePool(
        address indexed poolAddress,
        string name,
        string symbol,
        uint purchaseTokenCap,
        address indexed purchaseToken,
        uint duration,
        uint sponsorFee,
        address indexed sponsor,
        uint purchaseExpiry
    );
}
