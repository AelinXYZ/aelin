// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

contract AelinPoolFactory is MinimalProxyFactory {
    constructor() {}

    // @TODO update with correct address
    // address constant AELIN_POOL_ADDRESS = 0x0000000000000000000000000000000000000000;
    // @NOTE for integration testing we are going to add a setter for this until we launch the contract
    // on mainnet and can run using the mainnet address on a hardhat fork and can keep it hardcoded and remove the setter
    address AELIN_POOL_ADDRESS;

    // @TODO delete this before using on prod or sending for audits. Just for pre mainnet deploy integration tests
    function setAelinPoolAddress(address _aelin_pool_address) external {
        AELIN_POOL_ADDRESS = _aelin_pool_address;
    }

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
            string(abi.encodePacked("aeP-", _name)),
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
        address poolAddress,
        string name,
        string symbol,
        uint purchaseTokenCap,
        address purchaseToken,
        uint duration,
        uint sponsorFee,
        address sponsor,
        uint purchaseExpiry
    );
}
