// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MinimalProxyFactory.sol";
import "./AelinUpFrontDeal.sol";
import "./AelinPool.sol";
import "./interfaces/IAelinPool.sol";
import "./interfaces/IAelinDeal.sol";

contract AelinUpFrontDealFactory is MinimalProxyFactory {
    address public immutable AELIN_TREASURY;
    address public immutable AELIN_POOL_LOGIC;
    address public immutable AELIN_DEAL_LOGIC;
    address public immutable AELIN_ESCROW_LOGIC;
    address public immutable UP_FRONT_DEAL_LOGIC;

    constructor(
        address _aelinPoolLogic,
        address _aelinDealLogic,
        address _aelinTreasury,
        address _aelinEscrow,
        address _upFrontDealLogic
    ) {
        AELIN_POOL_LOGIC = _aelinPoolLogic;
        AELIN_DEAL_LOGIC = _aelinDealLogic;
        AELIN_TREASURY = _aelinTreasury;
        AELIN_ESCROW_LOGIC = _aelinEscrow;
        UP_FRONT_DEAL_LOGIC = _upFrontDealLogic;
    }

    function createPoolAndUpFrontDeal(
        IAelinPool.PoolData calldata _poolData,
        IAelinDeal.DealData calldata _dealData,
        uint256 _underlyingDealTokenAmount
    ) external returns (address poolAddress, address upFrontDealAddress) {
        require(_poolData.purchaseToken != address(0), "cant pass null token address");
        require(_dealData.openRedemptionPeriod == 0, "cant pass open redemption");

        poolAddress = _cloneAsMinimalProxy(AELIN_POOL_LOGIC, "Could not create new pool");
        AelinPool(poolAddress).initialize(_poolData, msg.sender, AELIN_DEAL_LOGIC, AELIN_TREASURY, AELIN_ESCROW_LOGIC);

        upFrontDealAddress = _cloneAsMinimalProxy(UP_FRONT_DEAL_LOGIC, "Could not create new deal");
        AelinUpFrontDeal(upFrontDealAddress).initializeUpFrontDeal(
            _poolData.name,
            _poolData.symbol,
            _dealData,
            _underlyingDealTokenAmount,
            address(this)
        );

        // events
    }
}
