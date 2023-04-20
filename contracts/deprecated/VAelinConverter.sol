// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Owned.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev a contract for converting vAELIN to AELIN tokens
 */

contract VAelinConverter is Owned {
    using SafeERC20 for IERC20;

    address public immutable vAELIN;
    address public immutable AELIN;
    uint256 public startTime;

    constructor(address _owner, address _vAelin, address _aelin) Owned(_owner) {
        vAELIN = _vAelin;
        AELIN = _aelin;
        startTime = block.timestamp;
    }

    function convertAll() external {
        convert(IERC20(vAELIN).balanceOf(msg.sender));
    }

    function convert(uint256 _amount) public {
        uint256 aelinAmount = ((_amount * 98) / 100);
        IERC20(vAELIN).transferFrom(msg.sender, address(this), _amount);
        IERC20(AELIN).transfer(msg.sender, aelinAmount);

        emit Converted(msg.sender, aelinAmount);
    }

    function _selfDestruct(address payable beneficiary) external onlyOwner {
        //only callable a year after end time
        require(block.timestamp > (startTime + 365 days), "Contract can only be selfdestruct after a year");

        IERC20(AELIN).transfer(beneficiary, IERC20(AELIN).balanceOf(address(this)));

        // selfdestruct(beneficiary);
    }

    event Converted(address sender, uint256 aelinReceived);
}
