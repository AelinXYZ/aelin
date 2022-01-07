// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/IMerkleDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Owned.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Pausable.sol";

contract MerkleDistributor is Owned, Pausable, IMerkleDistributor {
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    uint256 public startTime;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(
        address owner_,
        address token_,
        bytes32 merkleRoot_
    ) Owned(owner_) Pausable() {
        token = token_;
        merkleRoot = merkleRoot_;
        startTime = block.timestamp;
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
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        // Mark it claimed and send the token.
        _setClaimed(index);
        require(
            IERC20(token).transfer(account, amount),
            "MerkleDistributor: Transfer failed."
        );

        emit Claimed(index, account, amount);
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        //only callable a year after end time
        require(
            block.timestamp > (startTime + 30 days),
            "Contract can only be selfdestruct after a year"
        );

        IERC20(token).transfer(
            beneficiary,
            IERC20(token).balanceOf(address(this))
        );

        selfdestruct(beneficiary);
    }
}
