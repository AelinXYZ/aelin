// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Owned.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Pausable.sol";

/**
 * Contract which implements a merkle distribution for a given token
 * Based on an account balance snapshot stored in a merkle tree
 */
contract Distribution is Owned, Pausable {
    IERC20 public token;

    bytes32 public root; // merkle tree root

    uint256 public startTime;

    mapping(uint256 => uint256) public _claimed;

    constructor(
        address _owner,
        IERC20 _token,
        bytes32 _root
    ) Owned(_owner) Pausable() {
        token = _token;
        root = _root;
        startTime = block.timestamp;
    }

    // Check if a given reward has already been claimed
    function claimed(uint256 index)
        internal
        view
        returns (uint256 claimedBlock, uint256 claimedMask)
    {
        (claimedBlock, claimedMask) = _canClaim(index);
        require(
            ((claimedBlock & claimedMask) == 0),
            "Tokens have already been claimed"
        );
    }

    function canClaim(uint256 index) external view returns (bool) {
        (uint256 claimedBlock, uint256 claimedMask) = _canClaim(index);
        return ((claimedBlock & claimedMask) == 0);
    }

    function _canClaim(uint256 index)
        internal
        view
        returns (uint256 claimedBlock, uint256 claimedMask)
    {
        claimedBlock = _claimed[index / 256];
        claimedMask = (uint256(1) << uint256(index % 256));
    }

    // Get distributed tokens assigned to address
    // Requires sending merkle proof to the function
    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] memory merkleProof
    ) public notPaused {
        require(
            token.balanceOf(address(this)) > amount,
            "Contract doesnt have enough tokens"
        );

        // Make sure the tokens have not already been redeemed
        (uint256 claimedBlock, uint256 claimedMask) = claimed(index);
        _claimed[index / 256] = claimedBlock | claimedMask;

        // Compute the merkle leaf from index, recipient and amount
        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        // verify the proof is valid
        require(
            MerkleProof.verify(merkleProof, root, leaf),
            "Proof is not valid"
        );
        // Redeem!
        token.transfer(msg.sender, amount);
        emit Claim(msg.sender, amount, block.timestamp);
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        //only callable a year after end time
        require(
            block.timestamp > (startTime + 365 days),
            "Contract can only be selfdestruct after a year"
        );

        token.transfer(beneficiary, token.balanceOf(address(this)));

        selfdestruct(beneficiary);
    }

    event Claim(address claimer, uint256 amount, uint256 timestamp);
}
