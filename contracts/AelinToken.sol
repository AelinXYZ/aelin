// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/**
 * @dev a standard ERC20 contract that is extended with a few methods
 * described in detail below
 */
contract AelinToken is ERC20 {
    constructor() ERC20("Aelin Token", "AELIN") {}
}
