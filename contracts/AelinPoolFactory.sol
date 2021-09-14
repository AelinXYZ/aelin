// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

contract AelinPoolFactory is MinimalProxyFactory {
    address constant AELIN_REWARDS = 0x5A0b54D5dc17e0AadC383d2db43B0a0D3E029c4c;
    // NOTE that when we deploy these we can just hardcode them but for now since
    // create2 adds complexity I am adding setters below for testing purposes
    // that we will remove before deployment. Once we deploy since we are forking mainnet
    // we can just grab the contracts on our mainnet fork for testing instead of using create2
    address public AELIN_POOL_LOGIC;
    address public AELIN_DEAL_LOGIC;

    constructor() {}

    function setAddressesDeleteBeforeLaunch(address pool, address deal) external {
        AELIN_POOL_LOGIC = pool;
        AELIN_DEAL_LOGIC = deal;
    }

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
