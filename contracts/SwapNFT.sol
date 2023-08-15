// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {ISwapNFT} from "./interfaces/ISwapNFT.sol";

contract SwapNFT is ERC721, ISwapNFT {
    uint256 public tokenCount;

    mapping(address => bool) public hasMinted;

    constructor() ERC721("AelinSwapNFT", "SwapNFT") {}

    function mint() external {
        if (hasMinted[msg.sender]) revert CannotMintTwice();

        emit SwapNFTMinted(msg.sender, tokenCount);

        _mint(msg.sender, tokenCount);
        hasMinted[msg.sender] = true;
        tokenCount += 1;
    }

    function transferFrom(address, address, uint256) public pure override {
        revert NotTransferrable();
    }

    function safeTransferFrom(address, address, uint256) public pure override {
        revert NotTransferrable();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert NotTransferrable();
    }
}
