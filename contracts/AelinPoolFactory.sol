// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

contract AelinPoolFactory is MinimalProxyFactory {
    address constant AELIN_REWARDS = 0x5A0b54D5dc17e0AadC383d2db43B0a0D3E029c4c;
    address constant AELIN_POOL_LOGIC = 0xA08949CcAa0D8DcaF951611b95d58e74edF2Ec1e;
    address constant AELIN_DEAL_LOGIC = 0xfdbdb06109CD25c7F485221774f5f96148F1e235;

    constructor() {}

    function createPool(
        string memory _name,
        string memory _symbol,
        uint256 _purchaseTokenCap,
        address _purchaseToken,
        uint256 _duration,
        uint256 _sponsorFee,
        uint256 _purchaseExpiry
    ) external returns (address) {
        AelinPool aelin_pool = AelinPool(
            _cloneAsMinimalProxy(
                AELIN_POOL_LOGIC,
                "Could not create new deal"
            )
        );
        aelin_pool.initialize(
            _name,
            _symbol,
            _purchaseTokenCap,
            _purchaseToken,
            _duration,
            _sponsorFee,
            msg.sender,
            _purchaseExpiry,
            AELIN_DEAL_LOGIC,
            AELIN_REWARDS
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
        uint256 purchaseTokenCap,
        address indexed purchaseToken,
        uint256 duration,
        uint256 sponsorFee,
        address indexed sponsor,
        uint256 purchaseExpiry
    );
}
