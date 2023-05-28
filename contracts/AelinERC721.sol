// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @dev A standard ERC721 contract that is extended with a few additional functions and variables.
 * Due to the constructor being empty for the MinimalProxy architecture the customName and customSymbol
 * variables are set in the initializer. The MinimalProxy architecture also requires custom logic for
 * the name(), symbol(), and _setNameAndSymbol() functions.
 */
contract AelinERC721 is ERC721, ReentrancyGuard {
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
     * @notice This view function returns the name of the token.
     * @return string The name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return customName;
    }

    /**
     * @notice This view function returns the symbol of the token.
     * @return string The symbol of the token.
     */
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
