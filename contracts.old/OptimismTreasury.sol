// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Inheritance
import "./Owned.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OptimismTreasury is Owned {
    using SafeERC20 for IERC20;

    constructor(address _owner) Owned(_owner) {}

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}
