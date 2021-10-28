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
     * NOTE a pool factory v2 will be deployed when the staking rewards contract is live
     */
    address constant AELIN_REWARDS = 0x5A0b54D5dc17e0AadC383d2db43B0a0D3E029c4c;
    address public AELIN_POOL_LOGIC;
    address public AELIN_DEAL_LOGIC;

    constructor(address _aelinPoolLogic, address _aelinDealLogic) {
        AELIN_POOL_LOGIC = _aelinPoolLogic;
        AELIN_DEAL_LOGIC = _aelinDealLogic;
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
            _cloneAsMinimalProxy(AELIN_POOL_LOGIC, "Could not create new deal")
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
