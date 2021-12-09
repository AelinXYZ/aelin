// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev a standard ERC20 contract for the AELIN token
 */

contract AelinToken is ERC20 {
    constructor(address daoAddress) ERC20("Aelin Token", "AELIN") {
        _mint(daoAddress, 5000 * 10**decimals());
    }
}
