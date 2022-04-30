// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";
import {AelinPool} from "../contracts/AelinPool.sol";
import {AelinDeal} from "../contracts/AelinDeal.sol";
import {AelinPoolFactory} from "../contracts/AelinPoolFactory.sol";
import {IAelinPool} from "../contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Vm} from "forge-std/Vm.sol";

contract AelinPoolFactoryTest is DSTest {

    address public aelinRewards = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);

    AelinPool public pool;
    AelinDeal public deal;
    AelinPoolFactory public poolFactory;
    MockERC20 public purchaseToken;
    Vm public vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        pool = new AelinPool();
        deal = new AelinDeal();
        poolFactory = new AelinPoolFactory(address(pool), address(deal), aelinRewards);
        purchaseToken = new MockERC20("MockPool", "MP");
    }

    /*//////////////////////////////////////////////////////////////
                            createPool
    //////////////////////////////////////////////////////////////*/

    function testFuzzCreatePool(
        uint256 purchaseTokenCap,
        uint256 purchaseDuration,
        uint256 sponsorFee,
        uint256 duration
    ) public {
        vm.assume(purchaseTokenCap < 1e27);
        vm.assume(purchaseDuration >= 30 minutes);
        vm.assume(purchaseDuration <= 30 days);
        vm.assume(sponsorFee < 98e18);
        vm.assume(duration <= 365 days);

        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: purchaseTokenCap,
            purchaseToken: address(purchaseToken),
            duration: duration,
            sponsorFee: sponsorFee,
            purchaseDuration: purchaseDuration,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts
        });

        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), purchaseTokenCap);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + purchaseDuration);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + purchaseDuration + duration);
        assertEq(AelinPool(poolAddress).sponsorFee(), sponsorFee);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(deal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
    }

    function testCreatePoolAddresses() public {
        
        address[] memory allowListAddresses = new address[](3);
        uint256[] memory allowListAmounts = new uint256[](3);

        allowListAddresses[0] = address(0x1337);
        allowListAddresses[1] = address(0xBEEF);
        allowListAddresses[2] = address(0xDEED);

        allowListAmounts[0] = 1e18;
        allowListAmounts[1] = 1e18;
        allowListAmounts[2] = 1e18;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e27,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts
        });

        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e27);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), block.timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), block.timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(deal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(AelinPool(poolAddress).hasAllowList());

        for(uint256 i; i < allowListAddresses.length; ) {
            assertEq(AelinPool(poolAddress).allowList(allowListAddresses[i]), allowListAmounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function testFuzzCreatePoolTimestamp(uint256 timestamp) public {
        vm.assume(timestamp < 1e77);
        address[] memory allowListAddresses;
        uint256[] memory allowListAmounts;

        IAelinPool.PoolData memory poolData;
        poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseTokenCap: 1e18,
            purchaseToken: address(purchaseToken),
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: 20 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts
        });

        vm.warp(timestamp);
        address poolAddress = poolFactory.createPool(poolData);

        assertEq(AelinPool(poolAddress).name(), "aePool-POOL");
        assertEq(AelinPool(poolAddress).symbol(), "aeP-POOL");
        assertEq(AelinPool(poolAddress).decimals(), 18);
        assertEq(AelinPool(poolAddress).poolFactory(), address(poolFactory));
        assertEq(AelinPool(poolAddress).purchaseTokenCap(), 1e18);
        assertEq(AelinPool(poolAddress).purchaseToken(), address(purchaseToken));
        assertEq(AelinPool(poolAddress).purchaseExpiry(), timestamp + 20 days);
        assertEq(AelinPool(poolAddress).poolExpiry(), timestamp + 20 days + 30 days);
        assertEq(AelinPool(poolAddress).sponsorFee(), 2e18);
        assertEq(AelinPool(poolAddress).sponsor(), address(this));
        assertEq(AelinPool(poolAddress).aelinDealLogicAddress(), address(deal));
        assertEq(AelinPool(poolAddress).aelinRewardsAddress(), address(aelinRewards));
        assertTrue(!AelinPool(poolAddress).hasAllowList());
    }
}
