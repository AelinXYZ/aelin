// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev a standard ERC20 contract for the AELIN token
 */

contract VirtualAelinToken is ERC20 {
    constructor(address daoAddress) ERC20("Virtual Aelin Token", "vAELIN") {
        _mint(daoAddress, 765306122448980000000); // (750 / 0.98) * 10**decimals()
    }
}
