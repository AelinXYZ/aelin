// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error UnauthorizedMinter();
error InvalidAddress();

contract Aelin is ERC20, Ownable {
    // Initial supply set to 10M tokens as stated in AELIP-50
    uint256 public constant INITIAL_SUPPLY = 10 * 1e6 * 1e18;

    address public authorizedMinter;

    constructor(address _initialHolder) ERC20("Aelin", "AELIN") Ownable() {
        _mint(_initialHolder, INITIAL_SUPPLY);
    }

    function mint(address _receiver, uint256 _amount) external {
        if (msg.sender != authorizedMinter) revert UnauthorizedMinter();
        _mint(_receiver, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function setAuthorizedMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert InvalidAddress();
        authorizedMinter = _minter;
        emit MinterAuthorized(_minter);
    }

    event MinterAuthorized(address indexed minter);
}
