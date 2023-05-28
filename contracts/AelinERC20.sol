// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev A standard ERC20 contract that is extended with a few additional functions and variables.
 * Due to the constructor being empty for the MinimalProxy architecture the customName, customSymbol,
 * and customDecimals variables are set in the initializer. The MinimalProxy architecture also
 * requires custom logic for the name(), symbol(), decimals(), and _setNameSymbolAndDecimals()
 * functions.
 */
contract AelinERC20 is ERC20 {
    bool private setInfo;

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

    /**
     * @notice This view function returns the number of decimals the token has.
     * @return uint8 The number of decimals the token has.
     */
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
