// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ISwapNFT {
    error BalanceIsZero();
    error CannotMintTwice();
    error NotTransferrable();

    event SwapNFTMinted(address indexed minter, uint256 indexed tokenId);
}
