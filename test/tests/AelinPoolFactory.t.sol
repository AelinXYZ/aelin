// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";

contract AelinPoolFactoryTest is Test, AelinTestUtils {
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    uint256 public constant MAX_UINT_SAFE = 10_000_000_000_000_000_000_000_000;

    struct PoolVars {
        address[] allowListAddresses;
        uint256[] allowListAmounts;
        IAelinPool.NftCollectionRules[] nftCollectionRules;
        IAelinPool.PoolData poolData;
        AelinPool pool;
        AelinDeal deal;
        AelinFeeEscrow escrow;
        IAelinPool.NftPurchaseList[] nftPurchaseList;
        address dealAddress;
    }

    struct BoundedVars {
        uint256 sponsorFee;
        uint256 purchaseDuration;
        uint256 poolDuration;
        uint256 purchaseTokenCap;
    }

    enum PoolVarsNftCollection {
        ERC721,
        ERC1155,
        NONE
    }

    enum NftCollectionType {
        ERC1155,
        ERC721
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

    function setUp() public {}

    /*//////////////////////////////////////////////////////////////
                            helpers
    //////////////////////////////////////////////////////////////*/

    function getPoolVars(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        PoolVarsNftCollection nftListType
    ) internal returns (PoolVars memory) {
        PoolVars memory poolVars;

        if (nftListType == PoolVarsNftCollection.ERC721) {
            poolVars.nftCollectionRules = getNft721CollectionRules();
            poolVars.nftCollectionRules[0].purchaseAmount = 0;
            poolVars.nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
            poolVars.nftPurchaseList[0].collectionAddress = address(collection721_1);
            poolVars.nftPurchaseList[0].tokenIds = new uint256[](1);
            poolVars.nftPurchaseList[0].tokenIds[0] = 1;
        }

        if (nftListType == PoolVarsNftCollection.ERC1155) {
            poolVars.nftCollectionRules = getNft1155CollectionRules();
            poolVars.nftCollectionRules[0].collectionAddress = address(collection1155_1);
            poolVars.nftCollectionRules[0].purchaseAmount = 0;
            poolVars.nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
            poolVars.nftPurchaseList[0].collectionAddress = address(collection1155_1);
            poolVars.nftPurchaseList[0].tokenIds = new uint256[](1);
            poolVars.nftPurchaseList[0].tokenIds[0] = 1;
        }

        poolVars.poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: poolVars.allowListAddresses,
            allowListAmounts: poolVars.allowListAmounts,
            nftCollectionRules: poolVars.nftCollectionRules
        });
        poolVars.pool = new AelinPool();
        poolVars.escrow = new AelinFeeEscrow();
        poolVars.deal = new AelinDeal();

        return poolVars;
    }

    function boundVariables(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) internal returns (BoundedVars memory) {
        BoundedVars memory boundedVars;

        boundedVars.sponsorFee = bound(_sponsorFee, 0, MAX_SPONSOR_FEE);
        boundedVars.purchaseDuration = bound(_purchaseDuration, 30 minutes, 30 days);
        boundedVars.poolDuration = bound(_poolDuration, 0, 365 days);
        boundedVars.purchaseTokenCap = bound(_purchaseTokenCap, 100, MAX_UINT_SAFE);

        return boundedVars;
    }

    function testFuzz_createPool_RevertWhen_AelinPoolLogicAddressNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        vm.expectRevert("cant pass null pool address");
        new AelinPoolFactory(address(0), address(poolVars.deal), aelinTreasury, address(poolVars.escrow));
    }

    function testFuzz_createPool_RevertWhen_AelinDealLogicAddressNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        vm.expectRevert("cant pass null deal address");
        new AelinPoolFactory(address(poolVars.pool), address(0), aelinTreasury, address(poolVars.escrow));
    }

    function testFuzz_createPool_RevertWhen_AelinTreasuryLogicAddressNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        vm.expectRevert("cant pass null treasury address");
        new AelinPoolFactory(address(poolVars.pool), address(poolVars.deal), address(0), address(poolVars.escrow));
    }

    function testFuzz_createPool_RevertWhen_AelinEscrowLogicAddressNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        vm.expectRevert("cant pass null escrow address");
        new AelinPoolFactory(address(poolVars.pool), address(poolVars.deal), aelinTreasury, address(0));
    }

    function testFuzz_createPool_RevertWhen_PurchaseTokenAddressNull(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        poolVars.poolData.purchaseToken = address(0);

        AelinPoolFactory aelinFactory = new AelinPoolFactory(
            address(poolVars.pool),
            address(poolVars.deal),
            aelinTreasury,
            address(poolVars.escrow)
        );

        vm.expectRevert("cant pass null token address");
        aelinFactory.createPool(poolVars.poolData);
    }

    function testFuzz_createPool(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        AelinPoolFactory poolFactory = new AelinPoolFactory(
            address(poolVars.pool),
            address(poolVars.deal),
            aelinTreasury,
            address(poolVars.escrow)
        );

        vm.startPrank(user1);
        vm.expectEmit(false, true, true, true, address(poolFactory));
        emit CreatePool(
            address(0),
            "aePool-POOL",
            "aeP-POOL",
            boundedVars.purchaseTokenCap,
            address(purchaseToken),
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            user1,
            boundedVars.purchaseDuration,
            false
        );
        poolFactory.createPool(poolVars.poolData);
        vm.stopPrank();
    }

    function testFuzz_createPool_ERC721(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC721
        );

        AelinPoolFactory poolFactory = new AelinPoolFactory(
            address(poolVars.pool),
            address(poolVars.deal),
            aelinTreasury,
            address(poolVars.escrow)
        );

        vm.startPrank(user1);
        vm.expectEmit(false, true, true, true, address(poolFactory));
        emit CreatePool(
            address(0),
            "aePool-POOL",
            "aeP-POOL",
            boundedVars.purchaseTokenCap,
            address(purchaseToken),
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            user1,
            boundedVars.purchaseDuration,
            false
        );
        poolFactory.createPool(poolVars.poolData);
        vm.stopPrank();
    }

    function testFuzz_createPool_ERC1155(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.ERC1155
        );

        AelinPoolFactory poolFactory = new AelinPoolFactory(
            address(poolVars.pool),
            address(poolVars.deal),
            aelinTreasury,
            address(poolVars.escrow)
        );

        vm.startPrank(user1);
        vm.expectEmit(false, true, true, true, address(poolFactory));
        emit CreatePool(
            address(0),
            "aePool-POOL",
            "aeP-POOL",
            boundedVars.purchaseTokenCap,
            address(purchaseToken),
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            user1,
            boundedVars.purchaseDuration,
            false
        );
        poolFactory.createPool(poolVars.poolData);
        vm.stopPrank();
    }

    function testFuzz_createPool_AllowList(
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _poolDuration,
        uint256 _purchaseTokenCap,
        uint256 _allowListAmount
    ) public {
        BoundedVars memory boundedVars = boundVariables(_sponsorFee, _purchaseDuration, _poolDuration, _purchaseTokenCap);

        PoolVars memory poolVars = getPoolVars(
            boundedVars.purchaseTokenCap,
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            boundedVars.purchaseDuration,
            PoolVarsNftCollection.NONE
        );

        address[] memory allowListAddresses = new address[](1);
        uint256[] memory allowListAmounts = new uint256[](1);

        allowListAddresses[0] = address(user2);
        allowListAmounts[0] = _allowListAmount;

        poolVars.poolData.allowListAddresses = allowListAddresses;
        poolVars.poolData.allowListAmounts = allowListAmounts;

        AelinPoolFactory poolFactory = new AelinPoolFactory(
            address(poolVars.pool),
            address(poolVars.deal),
            aelinTreasury,
            address(poolVars.escrow)
        );

        vm.startPrank(user1);
        vm.expectEmit(false, true, true, true, address(poolFactory));
        emit CreatePool(
            address(0),
            "aePool-POOL",
            "aeP-POOL",
            boundedVars.purchaseTokenCap,
            address(purchaseToken),
            boundedVars.poolDuration,
            boundedVars.sponsorFee,
            user1,
            boundedVars.purchaseDuration,
            true
        );
        poolFactory.createPool(poolVars.poolData);
        vm.stopPrank();
    }
}
