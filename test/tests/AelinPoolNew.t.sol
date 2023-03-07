// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinPool} from "contracts/AelinPool.sol";
import {AelinDeal} from "contracts/AelinDeal.sol";
import {AelinPoolFactory} from "contracts/AelinPoolFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinDeal} from "contracts/interfaces/IAelinDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC20CustomDecimals} from "../mocks/MockERC20CustomDecimals.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockPunks} from "../mocks/MockPunks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AelinPoolTest is Test, AelinTestUtils {
    address public poolAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    AelinPoolFactory public poolFactory;
    AelinDeal public testDeal;

    MockERC20 public dealToken;
    MockERC20 public purchaseToken;
    MockERC721 public collectionAddressERC721_1;
    MockERC721 public collectionAddressERC721_2;
    MockERC721 public collectionAddressERC721_3;
    MockERC721 public collectionAddressERC721_4;
    MockERC1155 public collectionAddressERC1155_1;
    MockERC1155 public collectionAddressERC1155_2;
    MockERC1155 public collectionAddressERC1155_3;
    MockPunks public collectionAddressPunks;

    event Vouch(address indexed voucher);
    event Disavow(address indexed voucher);
    event SetSponsor(address indexed sponsor);
    event AllowlistAddress(address indexed purchaser, uint256 allowlistAmount);
    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount, bool purchaseAmountPerToken);
    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        bool purchaseAmountPerToken,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );
    event PurchasePoolToken(address indexed purchaser, uint256 purchaseTokenAmount);

    enum NftCollectionType {
        ERC1155,
        ERC721
    }

    function setUp() public {
        dealToken = new MockERC20("MockDeal", "MD");
        purchaseToken = new MockERC20("MockPool", "MP");
        collectionAddressERC721_1 = new MockERC721("TestCollection", "TC");
        collectionAddressERC721_2 = new MockERC721("TestCollection", "TC");
        collectionAddressERC721_3 = new MockERC721("TestCollection", "TC");
        collectionAddressERC721_4 = new MockERC721("TestCollection", "TC");
        collectionAddressERC1155_1 = new MockERC1155("testURI");
        collectionAddressERC1155_2 = new MockERC1155("testURI");
        collectionAddressERC1155_3 = new MockERC1155("testURI");
        collectionAddressPunks = new MockPunks();

        deal(address(purchaseToken), address(this), type(uint256).max);
        deal(address(dealToken), address(this), type(uint256).max);
        deal(address(purchaseToken), address(user1), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            helpers
    //////////////////////////////////////////////////////////////*/

    function getPoolData(
        uint256 purchaseTokenCap,
        uint256 duration,
        uint256 sponsorFee,
        uint256 purchaseDuration,
        address[] memory allowListAddresses,
        uint256[] memory allowListAmounts,
        IAelinPool.NftCollectionRules[] memory nftCollectionRules
    ) public view returns (IAelinPool.PoolData memory) {
        return
            IAelinPool.PoolData({
                name: "POOL",
                symbol: "POOL",
                purchaseToken: address(purchaseToken),
                purchaseTokenCap: purchaseTokenCap,
                duration: duration,
                sponsorFee: sponsorFee,
                purchaseDuration: purchaseDuration,
                allowListAddresses: allowListAddresses,
                allowListAmounts: allowListAmounts,
                nftCollectionRules: nftCollectionRules
            });
    }

    function getAllowListAddresses(uint256 length) public view returns (address[] memory) {
        address[] memory allowListAddresses = new address[](length);
        for (uint256 i; i < length; ++i) {
            allowListAddresses[i] = address(bytes20(sha256(abi.encodePacked(i, block.timestamp))));
        }
        return allowListAddresses;
    }

    function getAllowListAmounts(uint256 length) public pure returns (uint256[] memory) {
        uint256[] memory allowListAddresses = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            allowListAddresses[i] = i;
        }
        return allowListAddresses;
    }

    function getNft721CollectionRules() public view returns (IAelinPool.NftCollectionRules[] memory) {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](3);
        address[3] memory collectionsAddresses = [
            address(collectionAddressERC721_1),
            address(collectionAddressERC721_2),
            address(collectionAddressERC721_3)
        ];
        uint256 pseudoRandom;
        bool pperToken;
        for (uint256 i; i < 3; ++i) {
            pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 100_000_000;
            pperToken = pseudoRandom % 2 == 0;
            nftCollectionRules[i].collectionAddress = collectionsAddresses[i];
            nftCollectionRules[i].purchaseAmount = pseudoRandom;
            nftCollectionRules[i].purchaseAmountPerToken = pperToken;
        }
        return nftCollectionRules;
    }

    function getNft1155CollectionRules() public view returns (IAelinPool.NftCollectionRules[] memory) {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](3);
        address[3] memory collectionsAddresses = [
            address(collectionAddressERC1155_1),
            address(collectionAddressERC1155_2),
            address(collectionAddressERC1155_3)
        ];
        uint256 pseudoRandom;
        bool pperToken;
        for (uint256 i; i < 3; ++i) {
            pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 100_000_000;
            pperToken = pseudoRandom % 2 == 0;
            nftCollectionRules[i].collectionAddress = collectionsAddresses[i];
            nftCollectionRules[i].purchaseAmount = pseudoRandom;
            nftCollectionRules[i].purchaseAmountPerToken = pperToken;

            nftCollectionRules[i].tokenIds = new uint256[](2);
            nftCollectionRules[i].tokenIds[0] = 1;
            nftCollectionRules[i].tokenIds[1] = 2;

            nftCollectionRules[i].minTokensEligible = new uint256[](2);
            nftCollectionRules[i].minTokensEligible[0] = 10;
            nftCollectionRules[i].minTokensEligible[0] = 20;
        }
        return nftCollectionRules;
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
        MockERC20CustomDecimals customPurchaseToken = new MockERC20CustomDecimals(
            "MockCustomDecimals",
            "MP",
            _purchaseTokenDecimals
        );

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

    function testFuzz_Initialize_RevertWhen_AllowListIncorrect(uint256 _allowListAddresses, uint256 _allowListAmounts)
        public
    {
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
        nftCollectionRules[0].collectionAddress = address(collectionAddressERC721_1);
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        nftCollectionRules[1].collectionAddress = address(collectionAddressERC1155_1);
        nftCollectionRules[1].purchaseAmount = 0;
        nftCollectionRules[1].purchaseAmountPerToken = false;

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
        nftCollectionRules[0].collectionAddress = address(collectionAddressERC1155_1);
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        nftCollectionRules[1].collectionAddress = address(collectionAddressERC721_1);
        nftCollectionRules[1].purchaseAmount = 0;
        nftCollectionRules[1].purchaseAmountPerToken = false;

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

    function test_Initialize_RevertWhen_CollectionIncompatible() public {
        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        nftCollectionRules[0].collectionAddress = address(purchaseToken); // ERC20 not supported as NFT collection
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = false;

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
            emit PoolWith721(
                nftCollectionRules[i].collectionAddress,
                nftCollectionRules[i].purchaseAmount,
                nftCollectionRules[i].purchaseAmountPerToken
            );
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        for (uint256 i; i < 3; ++i) {
            (uint256 purchaseAmount, address collectionAddress, bool purchaseAmountPerToken) = pool.nftCollectionDetails(
                nftCollectionRules[i].collectionAddress
            );
            assertEq(collectionAddress, nftCollectionRules[i].collectionAddress, "Should have same collection address");
            assertEq(purchaseAmount, nftCollectionRules[i].purchaseAmount, "Should have same purchaseAmount");
            assertEq(
                purchaseAmountPerToken,
                nftCollectionRules[i].purchaseAmountPerToken,
                "Should have same purchaseAemountPerToken"
            );
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
                nftCollectionRules[i].purchaseAmountPerToken,
                nftCollectionRules[i].tokenIds,
                nftCollectionRules[i].minTokensEligible
            );
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        for (uint256 i; i < 3; ++i) {
            (uint256 purchaseAmount, address collectionAddress, bool purchaseAmountPerToken) = pool.nftCollectionDetails(
                nftCollectionRules[i].collectionAddress
            );
            assertEq(collectionAddress, nftCollectionRules[i].collectionAddress, "Should have same collection address");
            assertEq(purchaseAmount, nftCollectionRules[i].purchaseAmount, "Should have same purchaseAmount");
            assertEq(
                purchaseAmountPerToken,
                nftCollectionRules[i].purchaseAmountPerToken,
                "Should have same purchaseAemountPerToken"
            );
        }

        assertTrue(pool.hasNftList());
    }

    function testFuzz_Initialize_PoolPunks(
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

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = pseudoRandom;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

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
        emit PoolWith721(
            nftCollectionRules[0].collectionAddress,
            nftCollectionRules[0].purchaseAmount,
            nftCollectionRules[0].purchaseAmountPerToken
        );

        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        (uint256 purchaseAmount, address collectionAddress, bool purchaseAmountPerToken) = pool.nftCollectionDetails(
            nftCollectionRules[0].collectionAddress
        );
        assertEq(collectionAddress, nftCollectionRules[0].collectionAddress, "Should have same collection address");
        assertEq(purchaseAmount, nftCollectionRules[0].purchaseAmount, "Should have same purchaseAmount");
        assertEq(
            purchaseAmountPerToken,
            nftCollectionRules[0].purchaseAmountPerToken,
            "Should have same purchaseAemountPerToken"
        );

        assertTrue(pool.hasNftList());
    }

    function testFuzz_Initialize_PoolERC721AndPunks(
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

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](2);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = pseudoRandom;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        nftCollectionRules[1].collectionAddress = address(collectionAddressERC721_1);
        nftCollectionRules[1].purchaseAmount = pseudoRandom;
        nftCollectionRules[1].purchaseAmountPerToken = pperToken;

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
        for (uint256 i; i < 2; ++i) {
            emit PoolWith721(
                nftCollectionRules[i].collectionAddress,
                nftCollectionRules[i].purchaseAmount,
                nftCollectionRules[i].purchaseAmountPerToken
            );
        }
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        for (uint256 i; i < 2; ++i) {
            (uint256 purchaseAmount, address collectionAddress, bool purchaseAmountPerToken) = pool.nftCollectionDetails(
                nftCollectionRules[i].collectionAddress
            );
            assertEq(collectionAddress, nftCollectionRules[i].collectionAddress, "Should have same collection address");
            assertEq(purchaseAmount, nftCollectionRules[i].purchaseAmount, "Should have same purchaseAmount");
            assertEq(
                purchaseAmountPerToken,
                nftCollectionRules[i].purchaseAmountPerToken,
                "Should have same purchaseAemountPerToken"
            );
        }

        assertTrue(pool.hasNftList());
    }

    /*//////////////////////////////////////////////////////////////
                            purchasePoolTokens
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchasePoolTokens_RevertWhen_NotInPurchaseWindow(
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

        // Assert
        vm.warp(block.timestamp + _purchaseDuration);
        vm.expectRevert("not in purchase window");
        pool.purchasePoolTokens(10);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_HasNftList(
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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.expectRevert("has NFT list");
        pool.purchasePoolTokens(10);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_PurchaseMoreThanAllocation(
        uint256 _allowListAmount,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_purchaseTokenAmount > _allowListAmount);

        address[] memory allowListAddresses = new address[](1);
        uint256[] memory allowListAmounts = new uint256[](1);

        allowListAddresses[0] = address(user1);
        allowListAmounts[0] = _allowListAmount;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.expectRevert("more than allocation");
        pool.purchasePoolTokens(_purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokens_RevertWhen_CapExceeded(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenCap > 0);

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
        vm.assume(_purchaseTokenAmount > _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), type(uint256).max);
        vm.expectRevert("cap has been exceeded");
        pool.purchasePoolTokens(_purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokens_Pool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenCap > 0);

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
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true, address(pool));
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokens(_purchaseTokenAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            purchasePoolTokensWithNft
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotInPurchaseWindow(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.warp(block.timestamp + _purchaseDuration);
        vm.expectRevert("not in purchase window");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_HasNoNftList(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRulesEmpty;
        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);

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

        // Assert
        vm.expectRevert("pool does not have an NFT list");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_CollectionNotInPool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC1155_1);

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("collection not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_WalletAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collectionAddressERC721_1);
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 1 days,
            sponsorFee: _sponsorFee,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collectionAddressERC721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.expectRevert("wallet already used for nft set");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_PurchaseMoreThanAllocation(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collectionAddressERC721_2);

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("collection not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_CapExceeded(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount > _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collectionAddressERC721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        vm.expectRevert("cap has been exceeded");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotERC721Owner(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collectionAddressERC721_1).mint(user2, 1);
        vm.expectRevert("has to be the token owner");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC720TokenIdAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount < _purchaseTokenCap);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].collectionAddress = address(collectionAddressERC721_1);
        nftCollectionRules[0].purchaseAmount = _purchaseTokenAmount;
        nftCollectionRules[0].purchaseAmountPerToken = false;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        MockERC721(collectionAddressERC721_1).mint(user1, 1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        MockERC721(collectionAddressERC721_1).transferFrom(user1, user2, 1);
        vm.stopPrank();

        vm.startPrank(user2);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        vm.expectRevert("tokenId already used");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC1155TokenIdNotInPool(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 3; // Not in pool

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("tokenId not in the pool");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_ERC1155BalanceTooLow(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible,
        uint256 _userNftBalance
    ) public {
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_userNftBalance > 0);
        vm.assume(_minTokensEligible > _userNftBalance);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();
        nftCollectionRules[0].minTokensEligible[0] = _minTokensEligible;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: _poolDuration,
            sponsorFee: 0,
            purchaseDuration: _purchaseDuration,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("erc1155 balance too low");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_NotPunkOwner(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = pseudoRandom;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 1 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        vm.expectRevert("not the owner");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_RevertWhen_PunkTokenIdAlreadyUsed(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenCap > 0);
        vm.assume(_purchaseTokenCap > _purchaseTokenAmount);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.expectRevert("tokenId already used");
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC721(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC721_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockERC721(collectionAddressERC721_1).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolPunks(
        uint256 _purchaseTokenCap,
        uint256 _purchaseTokenAmount,
        uint256 _minTokensEligible
    ) public {
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);
        vm.assume(_minTokensEligible > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](1);
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC721AndPunks(uint256 _purchaseTokenCap, uint256 _purchaseTokenAmount)
        public
    {
        vm.assume(_purchaseTokenAmount > 0 && _purchaseTokenAmount <= 1000 ether);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft721CollectionRules();
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100_000_000;
        bool pperToken = pseudoRandom % 2 == 0;
        nftCollectionRules[0].collectionAddress = punks;
        nftCollectionRules[0].purchaseAmount = 0;
        nftCollectionRules[0].purchaseAmountPerToken = pperToken;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](2);
        nftPurchaseList[0].collectionAddress = punks;
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

        nftPurchaseList[1].collectionAddress = address(collectionAddressERC721_2);
        nftPurchaseList[1].tokenIds = new uint256[](1);
        nftPurchaseList[1].tokenIds[0] = 1;

        IAelinPool.PoolData memory poolData = getPoolData({
            purchaseTokenCap: _purchaseTokenCap,
            duration: 30 days,
            sponsorFee: 0,
            purchaseDuration: 10 days,
            allowListAddresses: allowListAddressesEmpty,
            allowListAmounts: allowListAmountsEmpty,
            nftCollectionRules: nftCollectionRules
        });

        AelinPool pool = new AelinPool();
        AelinFeeEscrow escrow = new AelinFeeEscrow();
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());
        bytes memory punksContractCode = address(collectionAddressPunks).code;
        vm.etch(punks, punksContractCode);

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockPunks(punks).mint(user1, 1);
        MockERC721(collectionAddressERC721_2).mint(user1, 1);
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }

    function testFuzz_PurchasePoolTokensWithNft_PoolERC1155(
        uint256 _purchaseTokenCap,
        uint256 _poolDuration,
        uint256 _sponsorFee,
        uint256 _purchaseDuration,
        uint256 _purchaseTokenAmount
    ) public {
        vm.assume(_sponsorFee <= MAX_SPONSOR_FEE);
        vm.assume(_purchaseDuration >= 30 minutes && _purchaseDuration <= 30 days);
        vm.assume(_poolDuration <= 365 days);
        vm.assume(_purchaseTokenAmount > 0);
        vm.assume(_purchaseTokenCap > 0);

        address[] memory allowListAddressesEmpty;
        uint256[] memory allowListAmountsEmpty;

        IAelinPool.NftCollectionRules[] memory nftCollectionRules = getNft1155CollectionRules();
        nftCollectionRules[0].purchaseAmount = 0;

        IAelinPool.NftPurchaseList[] memory nftPurchaseList = new IAelinPool.NftPurchaseList[](1);
        nftPurchaseList[0].collectionAddress = address(collectionAddressERC1155_1);
        nftPurchaseList[0].tokenIds = new uint256[](1);
        nftPurchaseList[0].tokenIds[0] = 1;

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
        pool.initialize(poolData, user1, address(testDeal), aelinTreasury, address(escrow));
        vm.assume(_purchaseTokenAmount <= _purchaseTokenCap - pool.totalSupply());

        // Assert
        vm.startPrank(user1);
        purchaseToken.approve(address(pool), _purchaseTokenAmount);
        MockERC1155(collectionAddressERC1155_1).mint(user1, 1, 100, "");
        emit PurchasePoolToken(user1, _purchaseTokenAmount);
        pool.purchasePoolTokensWithNft(nftPurchaseList, _purchaseTokenAmount);
        vm.stopPrank();
    }
}
