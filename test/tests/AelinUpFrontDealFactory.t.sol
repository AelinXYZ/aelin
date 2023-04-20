// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {AelinUpFrontDealFactory} from "contracts/AelinUpFrontDealFactory.sol";
import {AelinFeeEscrow} from "contracts/AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinNftGating} from "contracts/libraries/AelinNftGating.sol";

contract AelinUpFronDealFactoryTest is Test, AelinTestUtils {
    address public upfronDealAddress;
    address public poolAddressWith721;
    address public poolAddressWithAllowList;

    uint256 public constant MAX_UINT_SAFE = 100_000_000_000 * BASE;

    struct DealVars {
        AelinAllowList.InitData allowList;
        AelinNftGating.NftCollectionRules[] nftCollectionRules;
        IAelinUpFrontDeal.UpFrontDealData dealData;
        IAelinUpFrontDeal.UpFrontDealConfig dealConfig;
        AelinUpFrontDeal upFrontDealLogic;
        AelinFeeEscrow escrow;
        AelinNftGating.NftPurchaseList[] nftPurchaseList;
    }

    struct BoundedVars {
        uint256 sponsorFee;
        uint256 underlyingDealTokenTotal;
        uint256 purchaseTokenPerDealToken;
        uint256 purchaseRaiseMinimum;
        uint256 purchaseDuration;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        bool allowDeallocation;
    }

    enum UpFrontDealVarsNftCollection {
        ERC721,
        ERC1155,
        NONE
    }

    enum NftCollectionType {
        ERC1155,
        ERC721
    }

    event CreateUpFrontDeal(
        address indexed dealAddress,
        string name,
        string symbol,
        address purchaseToken,
        address underlyingDealToken,
        address indexed holder,
        address indexed sponsor,
        uint256 sponsorFee,
        bytes32 merkleRoot,
        string ipfsHash
    );

    event CreateUpFrontDealConfig(
        address indexed dealAddress,
        uint256 underlyingDealTokenTotal,
        uint256 purchaseTokenPerDealToken,
        uint256 purchaseRaiseMinimum,
        uint256 purchaseDuration,
        uint256 vestingPeriod,
        uint256 vestingCliffPeriod,
        bool allowDeallocation
    );

    function setUp() public {}

    /*//////////////////////////////////////////////////////////////
                            helpers
    //////////////////////////////////////////////////////////////*/

    function getUpFrontDealVars(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation,
        address _holder,
        address _sponsor
    ) internal returns (DealVars memory) {
        DealVars memory upFrontDealVars;

        upFrontDealVars.dealData = getUpFronDealData(_holder, _sponsor, _sponsorFee);
        upFrontDealVars.dealConfig = getUpFronDealConfig(
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            _allowDeallocation
        );

        upFrontDealVars.escrow = new AelinFeeEscrow();
        upFrontDealVars.upFrontDealLogic = new AelinUpFrontDeal();

        return upFrontDealVars;
    }

    function getUpFronDealData(
        address _holder,
        address _sponsor,
        uint256 _sponsorFee
    ) public view returns (IAelinUpFrontDeal.UpFrontDealData memory) {
        return
            IAelinUpFrontDeal.UpFrontDealData({
                name: "UF Deal",
                symbol: "UFD",
                purchaseToken: address(purchaseToken),
                underlyingDealToken: address(underlyingDealToken),
                holder: _holder,
                sponsor: _sponsor,
                sponsorFee: _sponsorFee,
                merkleRoot: bytes32(0),
                ipfsHash: "ipfsHash"
            });
    }

    function getUpFronDealConfig(
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public pure returns (IAelinUpFrontDeal.UpFrontDealConfig memory) {
        return
            IAelinUpFrontDeal.UpFrontDealConfig({
                underlyingDealTokenTotal: _underlyingDealTokenTotal,
                purchaseTokenPerDealToken: _purchaseTokenPerDealToken,
                purchaseRaiseMinimum: _purchaseRaiseMinimum,
                purchaseDuration: _purchaseDuration,
                vestingPeriod: _vestingPeriod,
                vestingCliffPeriod: _vestingCliffPeriod,
                allowDeallocation: _allowDeallocation
            });
    }

    function boundVariables(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod
    ) public returns (BoundedVars memory) {
        BoundedVars memory boundedVars;

        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseTokenPerDealToken > 0);
        vm.assume(_purchaseRaiseMinimum > 0);

        boundedVars.sponsorFee = bound(_sponsorFee, 0, MAX_SPONSOR_FEE);
        boundedVars.purchaseDuration = bound(_purchaseDuration, 30 minutes, 30 days);
        boundedVars.vestingPeriod = bound(_vestingPeriod, 0, 1825 days);
        boundedVars.vestingCliffPeriod = bound(_vestingCliffPeriod, 0, 1825 days);
        boundedVars.underlyingDealTokenTotal = bound(_underlyingDealTokenTotal, 1, MAX_UINT_SAFE);
        boundedVars.purchaseTokenPerDealToken = bound(
            _purchaseTokenPerDealToken,
            (10 ** (underlyingDealToken.decimals())) / boundedVars.underlyingDealTokenTotal,
            MAX_UINT_SAFE
        );
        boundedVars.purchaseRaiseMinimum = bound(
            _purchaseRaiseMinimum,
            1,
            (boundedVars.purchaseTokenPerDealToken * boundedVars.underlyingDealTokenTotal) /
                (10 ** underlyingDealToken.decimals())
        );

        return boundedVars;
    }

    function testFuzz_AelinUpFrontDealFactory_RevertWhen_AelinDealLogicAddressNull(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod
        );

        DealVars memory upFrontDealVars = getUpFrontDealVars(
            boundedVars.sponsorFee,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation,
            user2,
            user1
        );

        vm.expectRevert("cant pass null deal address");
        new AelinUpFrontDealFactory(address(0), address(upFrontDealVars.escrow), aelinTreasury);
    }

    function testFuzz_AelinUpFrontDealFactory_RevertWhen_AelinTreasuryAddressNull(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod
        );

        DealVars memory upFrontDealVars = getUpFrontDealVars(
            boundedVars.sponsorFee,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation,
            user2,
            user1
        );

        vm.expectRevert("cant pass null treasury address");
        new AelinUpFrontDealFactory(address(upFrontDealVars.upFrontDealLogic), address(upFrontDealVars.escrow), address(0));
    }

    function testFuzz_AelinUpFrontDealFactory_RevertWhen_AelinEscrowAddressNull(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod
        );

        DealVars memory upFrontDealVars = getUpFrontDealVars(
            boundedVars.sponsorFee,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation,
            user2,
            user1
        );

        vm.expectRevert("cant pass null escrow address");
        new AelinUpFrontDealFactory(address(upFrontDealVars.upFrontDealLogic), address(0), aelinTreasury);
    }

    function testFuzz_AelinUpFrontDealFactory_RevertWhen_SponsorIsNotSender(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod
        );

        DealVars memory upFrontDealVars = getUpFrontDealVars(
            boundedVars.sponsorFee,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation,
            user2,
            user1
        );

        AelinUpFrontDealFactory factory = new AelinUpFrontDealFactory(
            address(upFrontDealVars.upFrontDealLogic),
            address(upFrontDealVars.escrow),
            aelinTreasury
        );

        vm.prank(user3);
        vm.expectRevert("sponsor must be msg.sender");
        factory.createUpFrontDeal(
            upFrontDealVars.dealData,
            upFrontDealVars.dealConfig,
            upFrontDealVars.nftCollectionRules,
            upFrontDealVars.allowList
        );
    }

    function testFuzz_createUpFrontDeal(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        bool _allowDeallocation
    ) public {
        BoundedVars memory boundedVars = boundVariables(
            _sponsorFee,
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod
        );

        DealVars memory upFrontDealVars = getUpFrontDealVars(
            boundedVars.sponsorFee,
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation,
            user2,
            user1
        );

        AelinUpFrontDealFactory factory = new AelinUpFrontDealFactory(
            address(upFrontDealVars.upFrontDealLogic),
            address(upFrontDealVars.escrow),
            aelinTreasury
        );

        vm.startPrank(user1);
        vm.expectEmit(false, true, true, true, address(factory));
        emit CreateUpFrontDeal(
            address(0),
            "aeUpFrontDeal-UF Deal",
            "aeUD-UFD",
            address(purchaseToken),
            address(underlyingDealToken),
            user2,
            user1,
            boundedVars.sponsorFee,
            0,
            "ipfsHash"
        );

        vm.expectEmit(false, true, true, true, address(factory));
        emit CreateUpFrontDealConfig(
            address(0),
            boundedVars.underlyingDealTokenTotal,
            boundedVars.purchaseTokenPerDealToken,
            boundedVars.purchaseRaiseMinimum,
            boundedVars.purchaseDuration,
            boundedVars.vestingPeriod,
            boundedVars.vestingCliffPeriod,
            _allowDeallocation
        );
        factory.createUpFrontDeal(
            upFrontDealVars.dealData,
            upFrontDealVars.dealConfig,
            upFrontDealVars.nftCollectionRules,
            upFrontDealVars.allowList
        );
        vm.stopPrank();
    }
}
