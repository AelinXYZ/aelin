// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function tokenURI(uint256) public pure virtual override returns (string memory) {}

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        _burn(tokenId);
    }

    function transfer(
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        _safeTransfer(msg.sender, _to, _tokenId, _data);
    }
}
