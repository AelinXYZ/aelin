// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

/**
 * @dev the factory contract allows an Aelin sponsor to permissionlessly create new pools 
 */
contract AelinPoolFactory is MinimalProxyFactory {
    /**
     * TODO update with the correct multi-sig address
     */
    address constant AELIN_REWARDS = 0x5A0b54D5dc17e0AadC383d2db43B0a0D3E029c4c;
    /**
     * NOTE I am adding setters below for testing purposes that we will remove 
     * before deployment and hardcode the correct deployed addresses. Once we deploy 
     * we are forking mainnet in testing so we can use the real addresses in tests
     * this is the only piece of code that is meant to be temporary in the contracts
     */
    address public AELIN_POOL_LOGIC = 0xc5770D9bE37d5eFf77901854d5C74785C2e7C32F;
    address public AELIN_DEAL_LOGIC = 0xfE5F3046a0F37a7F74859827Fa20d1E1Fc8833b1;

    constructor() {}

    /**
     * @dev this will be deleted before we release the protocol. It is a helper for tests
     * but after we deploy the real contracts we will hardcode the values above
     */
    function setAddressesDeleteBeforeLaunch(address pool, address deal) external {
        AELIN_POOL_LOGIC = pool;
        AELIN_DEAL_LOGIC = deal;
    }

    /**
     * @dev the method a sponsor calls to create a pool
     */
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
