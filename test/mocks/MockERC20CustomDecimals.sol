// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20CustomDecimals is ERC20 {
    uint8 private custom_decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        custom_decimals = _decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return custom_decimals;
    }
}
