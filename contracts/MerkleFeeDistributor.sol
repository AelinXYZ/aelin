// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IMerkleFeeDistributor} from "./interfaces/IMerkleFeeDistributor.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MerkleFeeDistributor is Ownable, IMerkleFeeDistributor {
    using SafeERC20 for IERC20;

    uint256 public constant BASE = 1e18;

    // vSEY
    address public constant TOKEN1 = address(0x9eEcF010Bb8dc68A1a8783721E458f0917D0d7aa);
    uint256 public constant TOKEN1_AMOUNT = 7519488153057938939527000;
    // KWENTA
    address public constant TOKEN2 = address(0x920Cf626a271321C151D027030D5d08aF699456b);
    uint256 public constant TOKEN2_AMOUNT = 313372999999999999999;
    // vHECO
    address public constant TOKEN3 = address(0xED9353Dc0f12aC1E2F8120D60a4ACaa89a901F41);
    uint256 public constant TOKEN3_AMOUNT = 2047430070280000000000;
    // AELIN
    address public constant TOKEN4 = address(0x61BAADcF22d2565B0F471b291C475db5555e0b76);
    uint256 public constant TOKEN4_AMOUNT = 16846242936861671899;

    bytes32 public immutable override merkleRoot;

    mapping(uint256 => uint256) private claimedBitMap;

    constructor(bytes32 _merkleRoot) Ownable() {
        merkleRoot = _merkleRoot;
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
        require(!isClaimed(_index), "already claimed");

        // Verify the merkle proof.
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(_index, _account, _share))));
        require(MerkleProof.verify(_merkleProof, merkleRoot, node), "invalid proof");

        // Mark it claimed and send the token.
        _setClaimed(_index);

        IERC20(TOKEN1).safeTransfer(_account, _convertShareToAmount(_share, TOKEN1, TOKEN1_AMOUNT));
        IERC20(TOKEN2).safeTransfer(_account, _convertShareToAmount(_share, TOKEN2, TOKEN2_AMOUNT));
        IERC20(TOKEN3).safeTransfer(_account, _convertShareToAmount(_share, TOKEN3, TOKEN3_AMOUNT));
        IERC20(TOKEN4).safeTransfer(_account, _convertShareToAmount(_share, TOKEN4, TOKEN4_AMOUNT));

        emit Claimed(_index, _account, _share);
    }

    function withdrawAll() public onlyOwner {
        emit Withdrawn(owner(), TOKEN1, IERC20(TOKEN1).balanceOf(address(this)));
        IERC20(TOKEN1).safeTransfer(owner(), IERC20(TOKEN1).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN2, IERC20(TOKEN2).balanceOf(address(this)));
        IERC20(TOKEN2).safeTransfer(owner(), IERC20(TOKEN2).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN3, IERC20(TOKEN3).balanceOf(address(this)));
        IERC20(TOKEN3).safeTransfer(owner(), IERC20(TOKEN3).balanceOf(address(this)));

        emit Withdrawn(owner(), TOKEN4, IERC20(TOKEN4).balanceOf(address(this)));
        IERC20(TOKEN4).safeTransfer(owner(), IERC20(TOKEN4).balanceOf(address(this)));
    }

    function withdraw(address _token) public onlyOwner {
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        require(tokenBalance > 0, "balance is zero");

        emit Withdrawn(owner(), _token, tokenBalance);
        IERC20(_token).safeTransfer(owner(), tokenBalance);
    }

    event Withdrawn(address indexed to, address indexed token, uint256 amount);
}
