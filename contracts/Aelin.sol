// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error UnauthorizedMinter();
error InvalidAddress();

contract Aelin is ERC20, Ownable {
    /**
     * NOTE Set to 10M tokens as stated in AELIP-50.
     */
    uint256 public constant INITIAL_SUPPLY = 10 * 1e6 * 1e18;

    address public authorizedMinter;

    constructor(address _initialHolder) ERC20("Aelin", "AELIN") Ownable() {
        _mint(_initialHolder, INITIAL_SUPPLY);
    }

    /**
     * @notice The mint function for the Aelin token. Only the authorized minted can mint new tokens.
     * @param _receiver The recipient of the new tokens.
     * @param _amount The amount of tokens that will be recieved.
     */
    function mint(address _receiver, uint256 _amount) external {
        if (msg.sender != authorizedMinter) revert UnauthorizedMinter();
        _mint(_receiver, _amount);
    }

    /**
     * @notice The burn function for the Aelin token.
     * @param _amount The amount to be burned.
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /**
     * @notice This functions sets the authorized minter for the Aelin token.
     * @param _minter The new authorized minter.
     */
    function setAuthorizedMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert InvalidAddress();
        authorizedMinter = _minter;
        emit MinterAuthorized(_minter);
    }

    event MinterAuthorized(address indexed minter);
}
