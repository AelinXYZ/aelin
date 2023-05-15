// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev a standard ERC20 contract that is extended with a few methods
 * described in detail below
 */
contract AelinERC20 is ERC20 {
    bool private setInfo;
    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol in the initializer which requires these custom variables
     */
    string private customName;
    string private customSymbol;
    uint8 private customDecimals;

    uint8 constant DEAL_TOKEN_DECIMALS = 18;

    constructor() ERC20("", "") {}

    modifier initInfoOnce() {
        require(!setInfo, "can only initialize once");
        _;
    }

    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name, symbol, and decimals in the initializer which requires this
     * custom logic for name(), symbol(), decimals(), and _setNameSymbolAndDecimals()
     */
    function name() public view virtual override returns (string memory) {
        return customName;
    }

    function symbol() public view virtual override returns (string memory) {
        return customSymbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return customDecimals;
    }

    function _setNameSymbolAndDecimals(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) internal initInfoOnce returns (bool) {
        customName = _name;
        customSymbol = _symbol;
        customDecimals = _decimals;
        setInfo = true;
        emit AelinToken(_name, _symbol, _decimals);
        return true;
    }

    event AelinToken(string name, string symbol, uint8 decimals);
}
