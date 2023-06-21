// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error BalanceTooLow();
error AmountTooLow();
error Unauthorized();
error AwaitingDeposit();
error AlreadyDeposited();

contract AelinTokenSwapper {
    // Initial token supply set to 10M tokens as stated in AELIP-50
    uint256 public constant TOKEN_SUPPLY = 10 * 1e6 * 1e18;
    uint256 public constant OLD_TOKEN_SUPPLY = 5000 * 1e18;

    address public immutable aelinToken;
    address public immutable oldAelinToken;
    address public immutable aelinTreasury;

    bool public deposited;

    constructor(address _aelinToken, address _oldAelinToken, address _aelinTreasury) {
        aelinToken = _aelinToken;
        oldAelinToken = _oldAelinToken;
        aelinTreasury = _aelinTreasury;
    }

    function depositTokens() external {
        if (deposited == true) revert AlreadyDeposited();
        if (msg.sender != aelinTreasury) revert Unauthorized();
        IERC20(aelinToken).transferFrom(msg.sender, address(this), TOKEN_SUPPLY);
        deposited = true;
        emit TokenDeposited(msg.sender, TOKEN_SUPPLY);
    }

    function swap(uint256 _amount) external {
        if (deposited == false) revert AwaitingDeposit();
        if (_amount == 0) revert AmountTooLow();
        if (IERC20(oldAelinToken).balanceOf(msg.sender) < _amount) revert BalanceTooLow();
        IERC20(oldAelinToken).transferFrom(msg.sender, address(this), _amount);
        uint256 swapAmount = ((_amount * TOKEN_SUPPLY) / OLD_TOKEN_SUPPLY);
        IERC20(aelinToken).transfer(msg.sender, swapAmount);
        emit TokenSwapped(msg.sender, _amount, swapAmount);
    }

    event TokenDeposited(address indexed sender, uint256 amount);
    event TokenSwapped(address indexed sender, uint256 depositAmount, uint256 swapAmount);
}
