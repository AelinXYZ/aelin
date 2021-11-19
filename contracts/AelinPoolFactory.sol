// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";

/**
 * @dev the factory contract allows an Aelin sponsor to permissionlessly create new pools
 */
contract AelinPoolFactory is MinimalProxyFactory {
    address public immutable AELIN_REWARDS;
    address public immutable AELIN_POOL_LOGIC;
    address public immutable AELIN_DEAL_LOGIC;

    constructor(
        address _aelinPoolLogic,
        address _aelinDealLogic,
        address _aelinRewards
    ) {
        require(_aelinPoolLogic != address(0), "cant pass null pool address");
        require(_aelinDealLogic != address(0), "cant pass null deal address");
        require(_aelinRewards != address(0), "cant pass null rewards address");
        AELIN_POOL_LOGIC = _aelinPoolLogic;
        AELIN_DEAL_LOGIC = _aelinDealLogic;
        AELIN_REWARDS = _aelinRewards;
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
        uint256 _purchaseDuration,
        address[] memory _allowList,
        uint256[] memory _allowListAmounts
    ) external returns (address) {
        require(_purchaseToken != address(0), "cant pass null token address");
        address aelinPoolAddress = _cloneAsMinimalProxy(
            AELIN_POOL_LOGIC,
            "Could not create new deal"
        );
        AelinPool aelinPool = AelinPool(aelinPoolAddress);
        aelinPool.initialize(
            _name,
            _symbol,
            _purchaseTokenCap,
            _purchaseToken,
            _duration,
            _sponsorFee,
            msg.sender,
            _purchaseDuration,
            AELIN_DEAL_LOGIC,
            AELIN_REWARDS
        );
        if (_allowList.length > 0 || _allowListAmounts.length > 0) {
            require(
                _allowList.length == _allowListAmounts.length,
                "allowList array length issue"
            );
            aelinPool.updateAllowList(_allowList, _allowListAmounts);
        }

        emit CreatePool(
            aelinPoolAddress,
            string(abi.encodePacked("aePool-", _name)),
            string(abi.encodePacked("aeP-", _symbol)),
            _purchaseTokenCap,
            _purchaseToken,
            _duration,
            _sponsorFee,
            msg.sender,
            _purchaseDuration,
            _allowList.length > 0
        );

        return aelinPoolAddress;
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
        uint256 purchaseDuration,
        bool hasAllowList
    );
}
