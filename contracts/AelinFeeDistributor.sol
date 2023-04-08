// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMerkleDistributor} from "./interfaces/IMerkleDistributor.sol";

contract AelinFeeDistributor is Ownable, IMerkleDistributor {
    using SafeERC20 for IERC20;

    uint256 public immutable BASE = 1e18;

    address public immutable TOKEN1 = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address public immutable TOKEN2 = address(0x1f9840A85D5aF5BF1D1762f925BdaDdC4201f985);
    address public immutable TOKEN3 = address(0x1f9840A85D5Af5bf1d1762F925bDAddC4201F911);
    address public immutable TOKEN4 = address(0x1f9840A85d5af5BF1d1762F925BdaDDC4201F910);

    uint256 public immutable TOKEN1_AMOUNT = 100e18;
    uint256 public immutable TOKEN2_AMOUNT = 50e18;
    uint256 public immutable TOKEN3_AMOUNT = 25e18;
    uint256 public immutable TOKEN4_AMOUNT = 1e18;

    bytes32 public immutable override merkleRoot;
    uint256 public claimExpiry;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(bytes32 merkleRoot_) Ownable() {
        merkleRoot = merkleRoot_;
        claimExpiry = block.timestamp + 365 days;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function _convertShareToAmount(uint256 _share, address _token, uint256 _totalAmount) internal view returns (uint256) {
        uint256 claimableAmount = (_share * _totalAmount) / BASE;
        return
            IERC20(_token).balanceOf(address(this)) < claimableAmount
                ? IERC20(_token).balanceOf(address(this))
                : claimableAmount;
    }

    function claim(uint256 _index, address _account, uint256 _share, bytes32[] calldata _merkleProof) external override {
        require(!isClaimed(_index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(_index, _account, _share))));
        require(MerkleProof.verify(_merkleProof, merkleRoot, node), "MerkleDistributor: Invalid proof.");

        // Mark it claimed and send the token.
        _setClaimed(_index);

        IERC20(TOKEN1).safeTransfer(_account, _convertShareToAmount(_share, TOKEN1, TOKEN1_AMOUNT));
        IERC20(TOKEN2).safeTransfer(_account, _convertShareToAmount(_share, TOKEN2, TOKEN2_AMOUNT));
        IERC20(TOKEN3).safeTransfer(_account, _convertShareToAmount(_share, TOKEN3, TOKEN3_AMOUNT));
        IERC20(TOKEN4).safeTransfer(_account, _convertShareToAmount(_share, TOKEN4, TOKEN4_AMOUNT));

        emit Claimed(_index, _account, _share);
    }

    function withdraw() public onlyOwner {
        require(block.timestamp >= claimExpiry, "still in claimable window");

        emit Withdrawn(owner(), TOKEN1, IERC20(TOKEN1).balanceOf(address(this)));
        IERC20(TOKEN1).safeTransfer(owner(), IERC20(TOKEN1).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN2, IERC20(TOKEN2).balanceOf(address(this)));
        IERC20(TOKEN2).safeTransfer(owner(), IERC20(TOKEN2).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN3, IERC20(TOKEN3).balanceOf(address(this)));
        IERC20(TOKEN3).safeTransfer(owner(), IERC20(TOKEN3).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN4, IERC20(TOKEN4).balanceOf(address(this)));
        IERC20(TOKEN4).safeTransfer(owner(), IERC20(TOKEN4).balanceOf(address(this)));
    }

    event Withdrawn(address indexed to, address indexed token, uint256 amount);
}
