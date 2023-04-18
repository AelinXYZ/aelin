// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinNftGating} from "../../contracts/libraries/AelinNftGating.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {IAelinPool} from "contracts/interfaces/IAelinPool.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MerkleTree} from "../../contracts/libraries/MerkleTree.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MockPunks} from "../mocks/MockPunks.sol";

contract AelinTestUtils is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    uint256 constant BASE = 100 * 10 ** 18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 constant AELIN_FEE = 2 * 10 ** 18;
    uint8 constant DEAL_TOKEN_DECIMALS = 18;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);
    address user2 = address(0x1338);
    address user3 = address(0x1339);
    address user4 = address(0x1340);

    MockERC20 public underlyingDealToken = new MockERC20("MockDeal", "MD", 18);
    MockERC20 public underlyingDealTokenLowDecimals = new MockERC20("MockDeal", "MD", 2);
    MockERC20 public purchaseToken = new MockERC20("MockPurchase", "MP", 6);

    MockERC721 public collection721_1 = new MockERC721("TestCollection", "TC");
    MockERC721 public collection721_2 = new MockERC721("TestCollection", "TC");
    MockERC721 public collection721_3 = new MockERC721("TestCollection", "TC");
    MockERC721 public collection721_4 = new MockERC721("TestCollection", "TC");
    MockERC1155 public collection1155_1 = new MockERC1155("");
    MockERC1155 public collection1155_2 = new MockERC1155("");
    MockERC1155 public collection1155_3 = new MockERC1155("");
    MockPunks public collectionPunks = new MockPunks();

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;

    MerkleTree.UpFrontMerkleData public merkleDataEmpty;

    struct FuzzedUpFrontDeal {
        IAelinUpFrontDeal.UpFrontDealData dealData;
        IAelinUpFrontDeal.UpFrontDealConfig dealConfig;
        AelinUpFrontDeal upFrontDeal;
    }

    struct UpFrontDealVars {
        uint256 sponsorFee;
        uint256 underlyingDealTokenTotal;
        uint256 purchaseTokenPerDealToken;
        uint256 purchaseRaiseMinimum;
        uint256 purchaseDuration;
        uint256 vestingPeriod;
        uint256 vestingCliffPeriod;
        uint8 purchaseTokenDecimals;
        uint8 underlyingTokenDecimals;
    }

    function getCustomToken(uint8 _decimals) public returns (MockERC20) {
        return new MockERC20("CustomMockERC20", "CMT", _decimals);
    }

    function getFuzzDealData(
        uint8 _underlyingTokenDecimals,
        uint8 _purchaseTokenDecimals,
        address _holder,
        address _sponsor,
        uint256 _sponsorFee,
        string memory _ipfsHash,
        bytes32 _merkleRoot
    ) public returns (IAelinUpFrontDeal.UpFrontDealData memory) {
        MockERC20 customUnderlyingDealToken = getCustomToken(_underlyingTokenDecimals);
        MockERC20 customPurchaseToken = getCustomToken(_purchaseTokenDecimals);
        return
            IAelinUpFrontDeal.UpFrontDealData({
                name: "Fuzz DEAL",
                symbol: "FDEAL",
                purchaseToken: address(customPurchaseToken),
                underlyingDealToken: address(customUnderlyingDealToken),
                holder: _holder,
                sponsor: _sponsor,
                sponsorFee: _sponsorFee,
                ipfsHash: _ipfsHash,
                merkleRoot: _merkleRoot
            });
    }

    function getFuzzDealConfig(
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

    function getFuzzedDeal(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals
    ) public returns (FuzzedUpFrontDeal memory) {
        FuzzedUpFrontDeal memory fuzzedDeal;

        fuzzedDeal.dealData = getFuzzDealData(
            _underlyingTokenDecimals,
            _purchaseTokenDecimals,
            dealHolderAddress,
            dealCreatorAddress,
            _sponsorFee,
            "",
            0
        );
        fuzzedDeal.dealConfig = getFuzzDealConfig(
            _underlyingDealTokenTotal,
            _purchaseTokenPerDealToken,
            _purchaseRaiseMinimum,
            _purchaseDuration,
            _vestingPeriod,
            _vestingCliffPeriod,
            true
        );

        return fuzzedDeal;
    }

    function boundUpFrontDealVars(
        uint256 _sponsorFee,
        uint256 _underlyingDealTokenTotal,
        uint256 _purchaseTokenPerDealToken,
        uint256 _purchaseRaiseMinimum,
        uint256 _purchaseDuration,
        uint256 _vestingPeriod,
        uint256 _vestingCliffPeriod,
        uint8 _purchaseTokenDecimals,
        uint8 _underlyingTokenDecimals
    ) public returns (UpFrontDealVars memory) {
        UpFrontDealVars memory vars;

        vm.assume(_underlyingDealTokenTotal > 0);
        vm.assume(_purchaseTokenPerDealToken > 0);
        vm.assume(_purchaseRaiseMinimum > 0);

        // Bound variables
        vars.sponsorFee = bound(_sponsorFee, 0, MAX_SPONSOR_FEE);
        vars.purchaseTokenDecimals = uint8(bound(_purchaseTokenDecimals, 1, 18));
        vars.underlyingTokenDecimals = uint8(bound(_underlyingTokenDecimals, 1, 18));
        vars.underlyingDealTokenTotal = bound(vars.underlyingDealTokenTotal, 1000, 1000000 * BASE);
        vars.purchaseTokenPerDealToken = bound(
            _purchaseTokenPerDealToken,
            (10 ** (vars.underlyingTokenDecimals)) / vars.underlyingDealTokenTotal,
            1000000 * BASE
        );
        vars.purchaseRaiseMinimum = bound(
            _purchaseRaiseMinimum,
            1,
            (vars.purchaseTokenPerDealToken * vars.underlyingDealTokenTotal) / (10 ** vars.underlyingTokenDecimals)
        );
        vars.purchaseDuration = bound(_purchaseDuration, 30 minutes, 30 days);
        vars.vestingPeriod = bound(_vestingPeriod, 0, 1825 days);
        vars.vestingCliffPeriod = bound(_vestingCliffPeriod, 0, 1825 days);

        return vars;
    }

    function getDealData() public view returns (IAelinUpFrontDeal.UpFrontDealData memory) {
        return
            IAelinUpFrontDeal.UpFrontDealData({
                name: "DEAL",
                symbol: "DEAL",
                purchaseToken: address(purchaseToken),
                underlyingDealToken: address(underlyingDealToken),
                holder: dealHolderAddress,
                sponsor: dealCreatorAddress,
                sponsorFee: 1 * 10 ** 18,
                ipfsHash: "",
                merkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            });
    }

    function getDealConfigAllowDeallocation() public pure returns (IAelinUpFrontDeal.UpFrontDealConfig memory) {
        return
            IAelinUpFrontDeal.UpFrontDealConfig({
                underlyingDealTokenTotal: 1e35,
                purchaseTokenPerDealToken: 3e18,
                purchaseRaiseMinimum: 0,
                purchaseDuration: 10 days,
                vestingPeriod: 365 days,
                vestingCliffPeriod: 60 days,
                allowDeallocation: true
            });
    }

    function getDealConfig() public pure returns (IAelinUpFrontDeal.UpFrontDealConfig memory) {
        return
            IAelinUpFrontDeal.UpFrontDealConfig({
                underlyingDealTokenTotal: 1e35,
                purchaseTokenPerDealToken: 3e18,
                purchaseRaiseMinimum: 1e28,
                purchaseDuration: 10 days,
                vestingPeriod: 365 days,
                vestingCliffPeriod: 60 days,
                allowDeallocation: false
            });
    }

    function getAllowList() public view returns (AelinAllowList.InitData memory) {
        AelinAllowList.InitData memory allowList;

        address[] memory testAllowListAddresses = new address[](3);
        uint256[] memory testAllowListAmounts = new uint256[](3);
        testAllowListAddresses[0] = user1;
        testAllowListAddresses[1] = user2;
        testAllowListAddresses[2] = user3;
        testAllowListAmounts[0] = 1e18;
        testAllowListAmounts[1] = 2e18;
        testAllowListAmounts[2] = 3e18;
        allowList.allowListAddresses = testAllowListAddresses;
        allowList.allowListAmounts = testAllowListAmounts;
        return allowList;
    }

    function getERC721Collection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules721 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules721[0].collectionAddress = address(collection721_1);
        nftCollectionRules721[0].purchaseAmount = 1e20;
        nftCollectionRules721[1].collectionAddress = address(collection721_2);
        nftCollectionRules721[1].purchaseAmount = 1e22;

        return nftCollectionRules721;
    }

    function getERC721IdRanges() public pure returns (AelinNftGating.IdRange[] memory) {
        AelinNftGating.IdRange[] memory idRanges = new AelinNftGating.IdRange[](2);

        idRanges[0].begin = 1;
        idRanges[0].end = 2;

        idRanges[1].begin = 1e20;
        idRanges[1].end = 1e21;

        return idRanges;
    }

    function getERC1155Collection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules1155[0].collectionAddress = address(collection1155_1);
        nftCollectionRules1155[0].purchaseAmount = 0;
        nftCollectionRules1155[0].tokenIds = new uint256[](2);
        nftCollectionRules1155[0].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[0].tokenIds[0] = 1;
        nftCollectionRules1155[0].tokenIds[1] = 2;
        nftCollectionRules1155[0].minTokensEligible[0] = 10;
        nftCollectionRules1155[0].minTokensEligible[1] = 20;

        nftCollectionRules1155[1].collectionAddress = address(collection1155_2);
        nftCollectionRules1155[1].purchaseAmount = 0;
        nftCollectionRules1155[1].tokenIds = new uint256[](2);
        nftCollectionRules1155[1].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[1].tokenIds[0] = 10;
        nftCollectionRules1155[1].tokenIds[1] = 20;
        nftCollectionRules1155[1].minTokensEligible[0] = 1000;
        nftCollectionRules1155[1].minTokensEligible[1] = 2000;

        return nftCollectionRules1155;
    }

    function getPunksCollection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRulesPunks[0].collectionAddress = address(punks);
        nftCollectionRulesPunks[0].purchaseAmount = 1e22;

        return nftCollectionRulesPunks;
    }

    function setupAndAcceptDealNoDeallocation(address _dealAddress, uint256 _purchaseAmount, address _user) public {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (
            uint256 underlyingDealTokenTotal,
            uint256 purchaseTokenPerDealToken,
            uint256 purchaseRaiseMinimum,
            ,
            ,
            ,

        ) = AelinUpFrontDeal(_dealAddress).dealConfig();
        vm.assume(_purchaseAmount > purchaseRaiseMinimum);
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        vm.assume(poolSharesAmount < underlyingDealTokenTotal);

        // user accepts the deal with purchaseMinimum  < purchaseAmount < deal total
        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(_dealAddress, type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(_dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
    }

    function setupAndAcceptDealWithDeallocation(
        address _dealAddress,
        uint256 _purchaseAmount,
        address _user,
        bool isOverSubscribed
    ) public returns (uint256) {
        uint8 underlyingTokenDecimals = underlyingDealToken.decimals();
        (uint256 underlyingDealTokenTotal, uint256 purchaseTokenPerDealToken, , , , , ) = AelinUpFrontDeal(_dealAddress)
            .dealConfig();
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10 ** underlyingTokenDecimals);
        vm.assume(success);
        (success, ) = SafeMath.tryMul(_purchaseAmount, underlyingDealTokenTotal);
        vm.assume(success);

        uint256 poolSharesAmount = (_purchaseAmount * 10 ** underlyingTokenDecimals) / purchaseTokenPerDealToken;
        vm.assume(poolSharesAmount > 0);
        if (isOverSubscribed == true) {
            vm.assume(poolSharesAmount > underlyingDealTokenTotal);
        } else {
            vm.assume(poolSharesAmount <= underlyingDealTokenTotal);
        }

        deal(address(purchaseToken), _user, type(uint256).max);
        purchaseToken.approve(address(_dealAddress), type(uint256).max);
        AelinNftGating.NftPurchaseList[] memory nftPurchaseList;
        AelinUpFrontDeal(_dealAddress).acceptDeal(nftPurchaseList, merkleDataEmpty, _purchaseAmount);
        return (underlyingDealTokenTotal);
    }

    function purchaserClaim(address _dealAddress) public {
        // purchase period is now over
        reachPurchaseExpiry(_dealAddress);
        // purchaser claim
        AelinUpFrontDeal(_dealAddress).purchaserClaim();
    }

    function reachPurchaseExpiry(address _dealAddress) public {
        vm.warp(AelinUpFrontDeal(_dealAddress).purchaseExpiry() + 1 days);
    }

    function reachVestingCliffExpiry(address _dealAddress) public {
        vm.warp(AelinUpFrontDeal(_dealAddress).vestingCliffExpiry() + 1 days);
    }

    function reachVestingPeriod(address _dealAddress) public {
        vm.warp(AelinUpFrontDeal(_dealAddress).vestingCliffExpiry() + 1 days);
    }

    function makeAddr(uint256 num) internal returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(num)));
        addr = vm.addr(privateKey);
    }

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
            address(collection721_1),
            address(collection721_2),
            address(collection721_3)
        ];

        IAelinPool.IdRange[] memory idRanges = new IAelinPool.IdRange[](2);
        idRanges[0].begin = 1;
        idRanges[0].end = 2;
        idRanges[1].begin = 1e20;
        idRanges[1].end = 1e21;

        uint256 pseudoRandom;
        for (uint256 i; i < 3; ++i) {
            pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 100_000_000;
            nftCollectionRules[i].collectionAddress = collectionsAddresses[i];
            nftCollectionRules[i].purchaseAmount = pseudoRandom;
            nftCollectionRules[i].idRanges = idRanges;
        }
        return nftCollectionRules;
    }

    function getNft1155CollectionRules() public view returns (IAelinPool.NftCollectionRules[] memory) {
        IAelinPool.NftCollectionRules[] memory nftCollectionRules = new IAelinPool.NftCollectionRules[](3);
        address[3] memory collectionsAddresses = [
            address(collection1155_1),
            address(collection1155_2),
            address(collection1155_3)
        ];
        for (uint256 i; i < 3; ++i) {
            nftCollectionRules[i].collectionAddress = collectionsAddresses[i];
            nftCollectionRules[i].purchaseAmount = 0;

            nftCollectionRules[i].tokenIds = new uint256[](2);
            nftCollectionRules[i].tokenIds[0] = 1;
            nftCollectionRules[i].tokenIds[1] = 2;

            nftCollectionRules[i].minTokensEligible = new uint256[](2);
            nftCollectionRules[i].minTokensEligible[0] = 10;
            nftCollectionRules[i].minTokensEligible[0] = 20;
        }
        return nftCollectionRules;
    }
}
