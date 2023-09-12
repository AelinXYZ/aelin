// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {ISwapNFT} from "./interfaces/ISwapNFT.sol";

contract SwapNFT is ERC721, ISwapNFT {
    uint256 public tokenCount;
    string public constant BASE_URI =
        "https://v2.akord.com/vaults/active/boPGU8ShKj0KAcud8BLrzFGEkaIx5WlnBsVVhETG4ME/gallery#public/896532a7-b257-4997-8cf8-302435a915bb";

    mapping(address => bool) public hasMinted;

    constructor() ERC721("AelinSwapNFT", "SwapNFT") {}

    function mint() external {
        if (hasMinted[msg.sender]) revert CannotMintTwice();

        emit SwapNFTMinted(msg.sender, tokenCount);
        
        hasMinted[msg.sender] = true;
        tokenCount += 1;
        _mint(msg.sender, tokenCount);
    }

    function _baseURI() internal pure override returns (string memory) {
        return BASE_URI;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return _baseURI();
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
