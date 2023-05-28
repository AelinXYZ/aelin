// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library MerkleTree {
    struct UpFrontMerkleData {
        uint256 index;
        address account;
        uint256 amount;
        bytes32[] merkleProof;
    }

    struct TrackClaimed {
        mapping(uint256 => uint256) claimedBitMap;
    }

    /**
     * @notice This function allows users to verify their allocation in a deal with a merkle proof.
     * @dev Checks if the index leaf node is valid and if the user has purchased. It will set the index node
     * to purchased if approved.
     * @param merkleData The merkle data struct specifying the index, account, amount, and proof of a user's
     * allocation in a deal.
     * @param self The Bitmap storage location for tracking already claimed tokens using a merkle proof.
     * @param _purchaseTokenAmount The amount of tokens to purchase.
     * @param merkleRoot The merkle root used to verify the merkle data and a user's allocation.
     */
    function purchaseMerkleAmount(
        UpFrontMerkleData calldata merkleData,
        TrackClaimed storage self,
        uint256 _purchaseTokenAmount,
        bytes32 merkleRoot
    ) external {
        require(!hasPurchasedMerkle(self, merkleData.index), "Already purchased tokens");
        require(msg.sender == merkleData.account, "cant purchase others tokens");
        require(merkleData.amount >= _purchaseTokenAmount, "purchasing more than allowance");

        // Verify the merkle proof.
        bytes32 node = keccak256(
            bytes.concat(keccak256(abi.encode(merkleData.index, merkleData.account, merkleData.amount)))
        );
        require(MerkleProof.verify(merkleData.merkleProof, merkleRoot, node), "MerkleTree.sol: Invalid proof.");

        // Mark it claimed and send the token.
        _setPurchased(self, merkleData.index);
    }

    /**
     * @dev Sets the claimedBitMap to true for that index.
     */
    function _setPurchased(TrackClaimed storage self, uint256 _index) private {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        self.claimedBitMap[claimedWordIndex] = self.claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /**
     * @notice This is a view function that returns a boolean specifying whether or not an account has
     * has purchased tokens from a deal using a merkle proof.
     * @param self The Bitmap storage location for tracking already claimed tokens using a merkle proof.
     * @param _index The index of the merkle data to be tested.
     * @return bool Returns true if the index of the leaf node has purchased, and false if not.
     */
    function hasPurchasedMerkle(TrackClaimed storage self, uint256 _index) public view returns (bool) {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        uint256 claimedWord = self.claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }
}
