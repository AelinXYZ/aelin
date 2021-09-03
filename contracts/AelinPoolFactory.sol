// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

contract AelinPoolFactory is MinimalProxyFactory {
    constructor() {}

    address constant AELIN_POOL_ADDRESS = 0x491a5068ef5c0E9e317807e86B6a7Dfa6bC7f953;

    function createPool(
        string memory _name,
        string memory _symbol,
        uint _purchase_token_cap,
        address _purchase_token,
        uint _duration,
        uint _sponsor_fee,
        uint _purchase_expiry
    ) external returns (address) {
        AelinPool aelin_pool = AelinPool(_cloneAsMinimalProxy(AELIN_POOL_ADDRESS, "Could not create new deal"));
        aelin_pool.initialize(
            _name,
            _symbol,
            _purchase_token_cap,
            _purchase_token,
            _duration,
            _sponsor_fee,
            msg.sender,
            _purchase_expiry
        );

        emit CreatePool(
            address(aelin_pool),
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol)),
            _purchase_token_cap,
            _purchase_token,
            _duration,
            _sponsor_fee,
            msg.sender,
            _purchase_expiry
        );

        return address(aelin_pool);
    }

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
