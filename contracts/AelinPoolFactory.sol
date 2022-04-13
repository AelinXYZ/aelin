// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinPool.sol";
import "./interfaces/IAelinPoolFactory.sol";

/**
 * @dev the factory contract allows an Aelin sponsor to permissionlessly create new pools
 */
contract AelinPoolFactory is MinimalProxyFactory, IAelinPoolFactory {
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
        PoolData memory _poolData,
        address[] memory _allowList,
        uint256[] memory _allowListAmounts
    ) external override returns (address) {
        require(_poolData.purchaseToken != address(0), "cant pass null token address");
        address aelinPoolAddress = _cloneAsMinimalProxy(AELIN_POOL_LOGIC, "Could not create new deal");
        AelinPool aelinPool = AelinPool(aelinPoolAddress);
        aelinPool.initialize(
            _poolData,
            msg.sender,
            AELIN_DEAL_LOGIC,
            AELIN_REWARDS
        );
        if (_allowList.length > 0 || _allowListAmounts.length > 0) {
            require(_allowList.length == _allowListAmounts.length, "allowList array length issue");
            aelinPool.updateAllowList(_allowList, _allowListAmounts);
        }

        emit CreatePool(
            aelinPoolAddress,
            string(abi.encodePacked("aePool-", _poolData.name)),
            string(abi.encodePacked("aeP-", _poolData.symbol)),
            _poolData.purchaseTokenCap,
            _poolData.purchaseToken,
            _poolData.duration,
            _poolData.sponsorFee,
            msg.sender,
            _poolData.purchaseDuration,
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
