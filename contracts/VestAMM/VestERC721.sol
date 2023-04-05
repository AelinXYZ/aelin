// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IVestERC721} from "./interfaces/IVestERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VestERC721 is ERC721, ReentrancyGuard, IVestERC721 {
    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol in the initializer which requires these custom variables
     */
    string private _custom_name;
    string private _custom_symbol;

    bool infoSet;

    constructor() ERC721("", "") {}

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
        return _custom_name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _custom_symbol;
    }

    function _setNameAndSymbol(string memory _name, string memory _symbol) internal initInfoOnce returns (bool) {
        _custom_name = _name;
        _custom_symbol = _symbol;
        infoSet = true;
        emit SetVestERC721(_name, _symbol);
        return true;
    }
}
