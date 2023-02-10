// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IAelinUpFrontDeal} from "contracts/interfaces/IAelinUpFrontDeal.sol";
import {MerkleTree} from "../../contracts/libraries/MerkleTree.sol";
import {AelinNftGating} from "../../contracts/libraries/AelinNftGating.sol";
import {AelinUpFrontDeal} from "contracts/AelinUpFrontDeal.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AelinTestUtils is Test {
    address public aelinTreasury = address(0xfdbdb06109CD25c7F485221774f5f96148F1e235);
    address public punks = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

    uint256 constant BASE = 100 * 10 ** 18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 constant AELIN_FEE = 2 * 10 ** 18;

    address dealCreatorAddress = address(0xBEEF);
    address dealHolderAddress = address(0xDEAD);
    address user1 = address(0x1337);
    address user2 = address(0x1338);
    address user3 = address(0x1339);
    address user4 = address(0x1340);

    MockERC20 public underlyingDealToken = new MockERC20("MockDeal", "MD");
    MockERC20 public purchaseToken = new MockERC20("MockPurchase", "MP");

    MerkleTree.UpFrontMerkleData public merkleDataEmpty;

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
    ) public returns (uint256 underlyingDealTokenTotal) {
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
}
