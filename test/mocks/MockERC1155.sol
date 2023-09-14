// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public virtual {
        _mint(to, id, amount, data);
    }

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) public virtual {
        _burn(from, id, amount);
    }

    function batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) public virtual {
        _burnBatch(from, ids, amounts);
    }
}
