// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AelinERC721 is ERC721, ReentrancyGuard {
    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol in the initializer which requires these custom variables
     */
    string private customName;
    string private customSymbol;

    bool private infoSet;

    constructor() ERC721("", "") {}

    event SetAelinERC721(string name, string symbol);

    modifier initInfoOnce() {
        require(!infoSet, "can only initialize once");
        _;
    }

    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol, and decimals in the initializer which requires this
     * custom logic for name(), symbol(), and _setNameAndSymbol()
     */
    function name() public view virtual override returns (string memory) {
        return customName;
    }

    function symbol() public view virtual override returns (string memory) {
        return customSymbol;
    }

    function _setNameAndSymbol(string memory _name, string memory _symbol) internal initInfoOnce returns (bool) {
        customName = _name;
        customSymbol = _symbol;
        infoSet = true;
        emit SetAelinERC721(_name, _symbol);
        return true;
    }
}
