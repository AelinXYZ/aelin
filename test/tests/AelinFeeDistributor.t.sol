// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {AelinFeeDistributor} from "contracts/AelinFeeDistributor.sol";
import {IMerkleDistributor} from "contracts/interfaces/IMerkleDistributor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AelinFeeDistributorTest is Test {
    AelinFeeDistributor public feeDistributor;

    address public token1 = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    MockERC20 public mockToken1 = new MockERC20("Token1", "T1", 18);

    address public token2 = address(0x1f9840A85D5aF5BF1D1762f925BdaDdC4201f985);
    MockERC20 public mockToken2 = new MockERC20("Token2", "T2", 18);

    address public token3 = address(0x1f9840A85D5Af5bf1d1762F925bDAddC4201F911);
    MockERC20 public mockToken3 = new MockERC20("Token3", "T3", 18);

    address public token4 = address(0x1f9840A85d5af5BF1d1762F925BdaDDC4201F910);
    MockERC20 public mockToken4 = new MockERC20("Token4", "T4", 18);

    address public immutable deployer = address(0x123);
    address public immutable user1 = address(0x1111111111111111111111111111111111111111);
    address public immutable user2 = address(0x2222222222222222222222222222222222222222);
    address public immutable user3 = address(0x3333333333333333333333333333333333333333);

    bytes32 public immutable MERKLE_ROOT = 0x78d389c3740ecd7dd65296a9c12b783b990088e7715cc42f1c41b0541f19d63f;

    event Claimed(uint256 index, address account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdrawn(address indexed to, address indexed token, uint256 amount);

    function setUp() public {
        vm.startPrank(deployer);
        feeDistributor = new AelinFeeDistributor(MERKLE_ROOT);
        vm.stopPrank();

        bytes memory mockTokenCode;
        mockTokenCode = address(mockToken1).code;
        vm.etch(token1, mockTokenCode);

        mockTokenCode = address(mockToken2).code;
        vm.etch(token2, mockTokenCode);

        mockTokenCode = address(mockToken3).code;
        vm.etch(token3, mockTokenCode);

        mockTokenCode = address(mockToken4).code;
        vm.etch(token4, mockTokenCode);

        // we transfer the tokens to the contract
        deal(address(token1), address(feeDistributor), 100e18);
        deal(address(token2), address(feeDistributor), 50e18);
        deal(address(token3), address(feeDistributor), 25e18);
        deal(address(token4), address(feeDistributor), 1e18);
    }

    function test_CreateInstance() public {
        assertEq(feeDistributor.merkleRoot(), MERKLE_ROOT);
        assertEq(feeDistributor.claimExpiry(), block.timestamp + 365 days);
    }

    function test_Claim_RevertWhen_AlreadyClaimed() public {
        // user1 claims
        vm.startPrank(user1);
        uint256 share = 500000000000000000;
        uint256 claimableToken1 = (share * feeDistributor.TOKEN1_AMOUNT()) / 1e18;
        uint256 claimableToken2 = (share * feeDistributor.TOKEN2_AMOUNT()) / 1e18;
        uint256 claimableToken3 = (share * feeDistributor.TOKEN3_AMOUNT()) / 1e18;
        uint256 claimableToken4 = (share * feeDistributor.TOKEN4_AMOUNT()) / 1e18;

        bytes32[] memory merkleProof = new bytes32[](2);
        merkleProof[0] = 0x0a7e356738486e70683cadf436a6f14789f356637327b190e17ab338af7f0910;
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e48;
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken1);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken2);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken3);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken4);
        vm.expectEmit(false, false, false, true);
        emit Claimed(0, user1, share);
        feeDistributor.claim(0, user1, share, merkleProof);

        assertEq(MockERC20(token1).balanceOf(user1), claimableToken1);
        assertEq(MockERC20(token2).balanceOf(user1), claimableToken2);
        assertEq(MockERC20(token3).balanceOf(user1), claimableToken3);
        assertEq(MockERC20(token4).balanceOf(user1), claimableToken4);

        vm.expectRevert("MerkleDistributor: Drop already claimed.");
        feeDistributor.claim(0, user1, share, merkleProof);
        vm.stopPrank();
    }

    function test_Claim_RevertWhen_InvalidProof() public {
        vm.startPrank(user1);
        uint256 share = 500000000000000000;

        bytes32[] memory merkleProof = new bytes32[](2);
        merkleProof[0] = 0x0a7e356738486e70683cadf436a6f14789f356637327b190e17ab338af7f0910;
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e48;

        vm.expectRevert("MerkleDistributor: Invalid proof.");
        feeDistributor.claim(1, user1, share, merkleProof);

        vm.expectRevert("MerkleDistributor: Invalid proof.");
        feeDistributor.claim(0, user2, share, merkleProof);

        vm.expectRevert("MerkleDistributor: Invalid proof.");
        feeDistributor.claim(0, user1, 1, merkleProof);

        vm.expectRevert("MerkleDistributor: Invalid proof.");
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e43;
        feeDistributor.claim(0, user1, 1, merkleProof);

        vm.stopPrank();
    }

    function test_Claim() public {
        // user1 claims
        vm.startPrank(user1);
        uint256 share = 500000000000000000;
        uint256 claimableToken1 = (share * feeDistributor.TOKEN1_AMOUNT()) / 1e18;
        uint256 claimableToken2 = (share * feeDistributor.TOKEN2_AMOUNT()) / 1e18;
        uint256 claimableToken3 = (share * feeDistributor.TOKEN3_AMOUNT()) / 1e18;
        uint256 claimableToken4 = (share * feeDistributor.TOKEN4_AMOUNT()) / 1e18;

        bytes32[] memory merkleProof = new bytes32[](2);
        merkleProof[0] = 0x0a7e356738486e70683cadf436a6f14789f356637327b190e17ab338af7f0910;
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e48;
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken1);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken2);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken3);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken4);
        vm.expectEmit(false, false, false, true);
        emit Claimed(0, user1, share);
        feeDistributor.claim(0, user1, share, merkleProof);
        vm.stopPrank();

        assertEq(MockERC20(token1).balanceOf(user1), claimableToken1);
        assertEq(MockERC20(token2).balanceOf(user1), claimableToken2);
        assertEq(MockERC20(token3).balanceOf(user1), claimableToken3);
        assertEq(MockERC20(token4).balanceOf(user1), claimableToken4);

        // user2 claims
        vm.startPrank(user2);
        share = 250000000000000000;
        claimableToken1 = (share * feeDistributor.TOKEN1_AMOUNT()) / 1e18;
        claimableToken2 = (share * feeDistributor.TOKEN2_AMOUNT()) / 1e18;
        claimableToken3 = (share * feeDistributor.TOKEN3_AMOUNT()) / 1e18;
        claimableToken4 = (share * feeDistributor.TOKEN4_AMOUNT()) / 1e18;
        merkleProof[0] = 0x56c2f4d0add06504ab39e7fc2b6c831296e7383c12ab38fb55e731335981ea04;
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e48;
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user2, claimableToken1);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user2, claimableToken2);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user2, claimableToken3);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user2, claimableToken4);
        vm.expectEmit(false, false, false, true);
        emit Claimed(1, user2, share);
        feeDistributor.claim(1, user2, share, merkleProof);
        vm.stopPrank();

        assertEq(MockERC20(token1).balanceOf(user2), claimableToken1);
        assertEq(MockERC20(token2).balanceOf(user2), claimableToken2);
        assertEq(MockERC20(token3).balanceOf(user2), claimableToken3);
        assertEq(MockERC20(token4).balanceOf(user2), claimableToken4);

        // user3 claims
        vm.startPrank(user3);
        merkleProof = new bytes32[](1);
        merkleProof[0] = 0x98b8eb986285938cd978ef54f948bb535c80b5c6a2314ee893db0fe92b4d05ff;

        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user3, claimableToken1);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user3, claimableToken2);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user3, claimableToken3);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user3, claimableToken4);
        vm.expectEmit(false, false, false, true);
        emit Claimed(2, user3, share);
        feeDistributor.claim(2, user3, share, merkleProof);
        vm.stopPrank();

        assertEq(MockERC20(token1).balanceOf(user3), claimableToken1);
        assertEq(MockERC20(token2).balanceOf(user3), claimableToken2);
        assertEq(MockERC20(token3).balanceOf(user3), claimableToken3);
        assertEq(MockERC20(token4).balanceOf(user3), claimableToken4);

        assertEq(MockERC20(token1).balanceOf(address(feeDistributor)), 0);
        assertEq(MockERC20(token2).balanceOf(address(feeDistributor)), 0);
        assertEq(MockERC20(token3).balanceOf(address(feeDistributor)), 0);
        assertEq(MockERC20(token4).balanceOf(address(feeDistributor)), 0);
    }

    function testFuzz_Withdraw_RevertWhen_NotOwner(address _user) public {
        vm.assume(_user != deployer);
        vm.startPrank(_user);
        vm.expectRevert("Ownable: caller is not the owner");
        feeDistributor.withdraw();
        vm.stopPrank();
    }

    function test_Withdraw_RevertWhen_StillInClaimWindow() public {
        vm.startPrank(deployer);
        vm.expectRevert("still in claimable window");
        feeDistributor.withdraw();
        vm.stopPrank();
    }

    function test_Withdraw_NoClaims() public {
        vm.warp(block.timestamp + 365 days);

        assertEq(MockERC20(token1).balanceOf(deployer), 0);
        assertEq(MockERC20(token2).balanceOf(deployer), 0);
        assertEq(MockERC20(token3).balanceOf(deployer), 0);
        assertEq(MockERC20(token4).balanceOf(deployer), 0);

        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token1, MockERC20(token1).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token2, MockERC20(token2).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token3, MockERC20(token3).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token4, MockERC20(token4).balanceOf(address(feeDistributor)));
        feeDistributor.withdraw();
        vm.stopPrank();

        assertEq(MockERC20(token1).balanceOf(deployer), feeDistributor.TOKEN1_AMOUNT());
        assertEq(MockERC20(token2).balanceOf(deployer), feeDistributor.TOKEN2_AMOUNT());
        assertEq(MockERC20(token3).balanceOf(deployer), feeDistributor.TOKEN3_AMOUNT());
        assertEq(MockERC20(token4).balanceOf(deployer), feeDistributor.TOKEN4_AMOUNT());
    }

    function test_Withdraw_AfterClaims() public {
        assertEq(MockERC20(token1).balanceOf(deployer), 0);
        assertEq(MockERC20(token2).balanceOf(deployer), 0);
        assertEq(MockERC20(token3).balanceOf(deployer), 0);
        assertEq(MockERC20(token4).balanceOf(deployer), 0);

        // user 1 claims
        uint256 share = 500000000000000000;
        uint256 claimableToken1 = (share * feeDistributor.TOKEN1_AMOUNT()) / 1e18;
        uint256 claimableToken2 = (share * feeDistributor.TOKEN2_AMOUNT()) / 1e18;
        uint256 claimableToken3 = (share * feeDistributor.TOKEN3_AMOUNT()) / 1e18;
        uint256 claimableToken4 = (share * feeDistributor.TOKEN4_AMOUNT()) / 1e18;

        bytes32[] memory merkleProof = new bytes32[](2);
        merkleProof[0] = 0x0a7e356738486e70683cadf436a6f14789f356637327b190e17ab338af7f0910;
        merkleProof[1] = 0xac1fe0856a9ea8b0b37641df7cdd623f456573a64be32e4b28bb7bdf48024e48;

        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken1);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken2);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken3);
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(feeDistributor), user1, claimableToken4);
        vm.expectEmit(false, false, false, true);
        emit Claimed(0, user1, share);
        feeDistributor.claim(0, user1, share, merkleProof);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token1, MockERC20(token1).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token2, MockERC20(token2).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token3, MockERC20(token3).balanceOf(address(feeDistributor)));
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(deployer, token4, MockERC20(token4).balanceOf(address(feeDistributor)));
        feeDistributor.withdraw();
        vm.stopPrank();

        assertEq(MockERC20(token1).balanceOf(deployer), feeDistributor.TOKEN1_AMOUNT() - claimableToken1);
        assertEq(MockERC20(token2).balanceOf(deployer), feeDistributor.TOKEN2_AMOUNT() - claimableToken2);
        assertEq(MockERC20(token3).balanceOf(deployer), feeDistributor.TOKEN3_AMOUNT() - claimableToken3);
        assertEq(MockERC20(token4).balanceOf(deployer), feeDistributor.TOKEN4_AMOUNT() - claimableToken4);
    }
}
