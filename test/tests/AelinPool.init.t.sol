// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AelinPoolInitTest is Test, AelinTestUtils {
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    AelinPoolFactory public poolFactory;
    AelinDeal public testDeal;

    enum NftCollectionType {
        ERC1155,
        ERC721
    }

    event SetSponsor(address indexed sponsor);

    event AllowlistAddress(address indexed purchaser, uint256 allowlistAmount);

    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount);

    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );

    function setUp() public {
        deal(address(purchaseToken), address(this), type(uint256).max);
        deal(address(underlyingDealToken), address(this), type(uint256).max);
        deal(address(purchaseToken), address(user1), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            initialize
    //////////////////////////////////////////////////////////////*/

    //Revert scenarios
    function testFuzz_Initialize_RevertWhen_InitiatedTwice(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();

        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.expectRevert("can only initialize once");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_RevertWhen_WrongPurchaseDuration(uint256 _purchaseDuration) public {
        vm.assume(_purchaseDuration < 30 minutes || _purchaseDuration > 30 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 30 days,
            sponsorFee: 2e18,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("outside purchase expiry window");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_RevertWhen_WrongPoolDuration(uint256 _poolDuration) public {
        vm.assume(_poolDuration > 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: _poolDuration,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("max 1 year duration");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_RevertWhen_WrongSponsorFee(uint256 _sponsorFees) public {
        vm.assume(_sponsorFees > MAX_SPONSOR_FEE);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: _sponsorFees,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("exceeds max sponsor fee");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_RevertWhen_TooManyDecimals(uint8 _purchaseTokenDecimals) public {
        vm.assume(_purchaseTokenDecimals > DEAL_TOKEN_DECIMALS);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;
        MockERC20 customPurchaseToken = new MockERC20("MockCustomDecimals", "MP", _purchaseTokenDecimals);

        IAelinPool.PoolData memory poolData = IAelinPool.PoolData({
            name: "POOL",
            symbol: "POOL",
            purchaseToken: address(customPurchaseToken),
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 218,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("too many token decimals");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_RevertWhen_AllowListIncorrect(
        uint256 _allowListAddresses,
        uint256 _allowListAmounts
    ) public {
        vm.assume(_allowListAddresses < 100 && _allowListAmounts < 100); // Otherwise will run out of gas
        vm.assume(_allowListAddresses != _allowListAmounts);

        address[] memory allowListAddresses = new address[](_allowListAddresses);
        uint256[] memory allowListAmounts = new uint256[](_allowListAmounts);

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("allowListAddresses and allowListAmounts arrays should have the same length");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_NotOnlyERC721() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);
        nftCollectionRules[0].collectionAddress = address(collection721_1);
        nftCollectionRules[0].purchaseAmount = 0;

        nftCollectionRules[1].collectionAddress = address(collection1155_1);
        nftCollectionRules[1].purchaseAmount = 0;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("can only contain 721");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_NotOnlyERC1155() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);
        nftCollectionRules[0].collectionAddress = address(collection1155_1);
        nftCollectionRules[0].purchaseAmount = 0;

        nftCollectionRules[1].collectionAddress = address(collection721_1);
        nftCollectionRules[1].purchaseAmount = 0;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("can only contain 1155");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_1155CollectionRulesPurchaseAmtNotZero() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        nftCollectionRules[0].collectionAddress = address(collection1155_1);
        nftCollectionRules[0].purchaseAmount = 1; //Not zero

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("purchase amt must be 0 for 1155");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_CollectionIncompatible() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        nftCollectionRules[0].collectionAddress = address(purchaseToken); // ERC20 not supported as NFT collection
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("collection is not compatible");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_MaxIdRangesExceeded() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        nftCollectionRules[0].collectionAddress = address(collection721_1);
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.IdRange[] memory idRanges = new IAelinPool.IdRange[](11);

        for (uint256 i; i < 11; i++) {
            idRanges[i].begin = 0;
            idRanges[i].end = 1;
        }

        nftCollectionRules[0].idRanges = idRanges;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("too many ranges");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function test_Initialize_RevertWhen_IdRangesAreIncorrect() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesA = getNft721CollectionRules();

        //First element of CollectionRules, first element of idRanges
        nftCollectionRulesA[0].idRanges[0].begin = 1;
        nftCollectionRulesA[0].idRanges[0].end = 0;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesA
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        vm.expectRevert("begin greater than end");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        //First element of CollectionRules, second element of idRanges
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesB = getNft721CollectionRules();
        nftCollectionRulesB[0].idRanges[1].begin = 1;
        nftCollectionRulesB[0].idRanges[1].end = 0;

        poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesB
        });

        vm.expectRevert("begin greater than end");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        //Second element of CollectionRules, first element of idRanges
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesC = getNft721CollectionRules();
        nftCollectionRulesC[1].idRanges[0].begin = 1;
        nftCollectionRulesC[1].idRanges[0].end = 0;

        poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesC
        });

        vm.expectRevert("begin greater than end");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        //Second element of CollectionRules, first element of idRanges
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesD = getNft721CollectionRules();
        nftCollectionRulesD[1].idRanges[1].begin = 1;
        nftCollectionRulesD[1].idRanges[1].end = 0;

        poolData = getPoolData({
            purchaseTokenCap: 1e35,
            duration: 10 days,
            sponsorFee: 2e18,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesD
        });

        vm.expectRevert("begin greater than end");
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
    }

    function testFuzz_Initialize_Pool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;
        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();

        vm.expectEmit(true, true, true, true, address(pool));
        emit SetSponsor(user1);
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        assertEq(pool.name(), "aePool-POOL");
        assertEq(pool.symbol(), "aeP-POOL");
        assertEq(pool.decimals(), purchaseToken.decimals());
        assertEq(pool.poolFactory(), address(this));
        assertEq(pool.purchaseTokenCap(), _purchaseTokenCap);
        assertEq(pool.purchaseToken(), address(purchaseToken));
        assertEq(pool.purchaseExpiry(), block.timestamp + _purchaseDuration);
        assertEq(pool.poolExpiry(), block.timestamp + _purchaseDuration + _poolDuration);
        assertEq(pool.sponsorFee(), _sponsorFee);
        assertEq(pool.sponsor(), user1);
        assertEq(pool.aelinDealLogicAddress(), address(testDeal));
        assertEq(pool.aelinTreasuryAddress(), address(aelinTreasury));
        assertFalse(pool.hasAllowList());
        assertFalse(pool.hasNftList());
    }

    function testFuzz_Initialize_PoolWithAllowList(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _allowListLength
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_allowListLength < 100 && _allowListLength > 0); // Otherwise will run out of gas

        address[] memory allowListAddresses = getAllowListAddresses(_allowListLength);
        uint256[] memory allowListAmounts = getAllowListAmounts(_allowListLength);

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddresses,
            allowListAmounts: allowListAmounts,
            nftCollectionRules: nftCollectionRulesEmpty
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();

        vm.expectEmit(true, true, true, true, address(pool));
        for (uint256 i; i < _allowListLength; ++i) {
            emit AllowlistAddress(allowListAddresses[i], allowListAmounts[i]);
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        assertFalse(pool.hasNftList());
        assertTrue(pool.hasAllowList());
        for (uint256 i; i < _allowListLength; ++i) {
            assertEq(
                pool.allowList(allowListAddresses[i]),
                allowListAmounts[i],
                "allowList address/amounts should be correct"
            );
        }
    }

    function testFuzz_Initialize_PoolERC721(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();

        vm.expectEmit(true, true, true, true, address(pool));
        for (uint256 i; i < 3; ++i) {
            emit PoolWith721(nftCollectionRules[i].collectionAddress, nftCollectionRules[i].purchaseAmount);
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        for (uint256 i; i < 3; ++i) {
            (uint256 purchaseAmount, address collectionAddress) = pool.nftCollectionDetails(
                nftCollectionRules[i].collectionAddress
            );
            assertEq(collectionAddress, nftCollectionRules[i].collectionAddress, "Should have same collection address");
            assertEq(purchaseAmount, nftCollectionRules[i].purchaseAmount, "Should have same purchaseAmount");
        }

        assertTrue(pool.hasNftList());
    }

    function testFuzz_Initialize_PoolERC1155(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: _sponsorFee,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();

        vm.expectEmit(true, true, true, true, address(pool));
        for (uint256 i; i < 3; ++i) {
            emit PoolWith1155(
                nftCollectionRules[i].collectionAddress,
                nftCollectionRules[i].purchaseAmount,
                nftCollectionRules[i].tokenIds,
                nftCollectionRules[i].minTokensEligible
            );
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        for (uint256 i; i < 3; ++i) {
            (uint256 purchaseAmount, address collectionAddress) = pool.nftCollectionDetails(
                nftCollectionRules[i].collectionAddress
            );
            assertEq(collectionAddress, nftCollectionRules[i].collectionAddress, "Should have same collection address");
            assertEq(purchaseAmount, nftCollectionRules[i].purchaseAmount, "Should have same purchaseAmount");
        }

        assertTrue(pool.hasNftList());
    }
}
