// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinAllowList} from "contracts/libraries/AelinAllowList.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {AelinNftGating} from "../../contracts/libraries/AelinNftGating.sol";
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

    uint256 constant BASE = 100 * 10**18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10**18;
    uint256 public constant AELIN_FEE = 2 * 10**18;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);
    address user2 = address(0x1338);
    address user3 = address(0x1339);
    address user4 = address(0x1340);

    MockERC20 public underlyingDealToken = new MockERC20("MockDeal", "MD");
    MockERC20 public purchaseToken = new MockERC20("MockPurchase", "MP");

    MockERC721 public collection721_1 = new MockERC721("TestCollection", "TC");
    MockERC721 public collection721_2 = new MockERC721("TestCollection", "TC");
    MockERC721 public collection721_3 = new MockERC721("TestCollection", "TC");
    MockERC1155 public collection1155_1 = new MockERC1155("");
    MockERC1155 public collection1155_2 = new MockERC1155("");
    MockPunks public collectionPunks = new MockPunks();

    AelinNftGating.NftCollectionRules[] public nftCollectionRulesEmpty;

    MerkleTree.UpFrontMerkleData public merkleDataEmpty;

    function getDealData() public view returns (IAelinUpFrontDeal.UpFrontDealData memory) {
        return
            IAelinUpFrontDeal.UpFrontDealData({
                name: "DEAL",
                symbol: "DEAL",
                purchaseToken: address(purchaseToken),
                underlyingDealToken: address(underlyingDealToken),
                holder: dealHolderAddress,
                sponsor: dealCreatorAddress,
                sponsorFee: 1 * 10**18,
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
        nftCollectionRules721[0].purchaseAmountPerToken = true;
        nftCollectionRules721[1].collectionAddress = address(collection721_2);
        nftCollectionRules721[1].purchaseAmount = 1e22;
        nftCollectionRules721[1].purchaseAmountPerToken = false;

        return nftCollectionRules721;
    }

    function getERC1155Collection() public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules1155 = new AelinNftGating.NftCollectionRules[](2);

        nftCollectionRules1155[0].collectionAddress = address(collection1155_1);
        nftCollectionRules1155[0].purchaseAmount = 1e20;
        nftCollectionRules1155[0].purchaseAmountPerToken = true;
        nftCollectionRules1155[0].tokenIds = new uint256[](2);
        nftCollectionRules1155[0].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[0].tokenIds[0] = 1;
        nftCollectionRules1155[0].tokenIds[1] = 2;
        nftCollectionRules1155[0].minTokensEligible[0] = 10;
        nftCollectionRules1155[0].minTokensEligible[1] = 20;
        nftCollectionRules1155[1].collectionAddress = address(collection1155_2);
        nftCollectionRules1155[1].purchaseAmount = 1e22;
        nftCollectionRules1155[1].purchaseAmountPerToken = false;
        nftCollectionRules1155[1].tokenIds = new uint256[](2);
        nftCollectionRules1155[1].minTokensEligible = new uint256[](2);
        nftCollectionRules1155[1].tokenIds[0] = 10;
        nftCollectionRules1155[1].tokenIds[1] = 20;
        nftCollectionRules1155[1].minTokensEligible[0] = 1000;
        nftCollectionRules1155[1].minTokensEligible[1] = 2000;

        return nftCollectionRules1155;
    }

    function getPunksCollection(bool _purchaseIsPerToken) public view returns (AelinNftGating.NftCollectionRules[] memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRulesPunks = new AelinNftGating.NftCollectionRules[](1);

        nftCollectionRulesPunks[0].collectionAddress = address(punks);
        nftCollectionRulesPunks[0].purchaseAmount = 1e22;
        nftCollectionRulesPunks[0].purchaseAmountPerToken = _purchaseIsPerToken;

        return nftCollectionRulesPunks;
    }

    function setupAndAcceptDealNoDeallocation(
        address _dealAddress,
        uint256 _purchaseAmount,
        address _user
    ) public {
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
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
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
        (bool success, ) = SafeMath.tryMul(_purchaseAmount, 10**underlyingTokenDecimals);
        vm.assume(success);
        (success, ) = SafeMath.tryMul(_purchaseAmount, underlyingDealTokenTotal);
        vm.assume(success);

        uint256 poolSharesAmount = (_purchaseAmount * 10**underlyingTokenDecimals) / purchaseTokenPerDealToken;
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
}
