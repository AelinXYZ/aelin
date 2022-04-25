// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinFeeEscrow {
    using SafeERC20 for IERC20;
    uint256 public vestingExpiry;
    address public treasury;
    address public futureTreasury;

    bool public calledInitialize;

    constructor() {}

    /**
     * @dev the treasury may change their address
     */
    function setTreasury(address _treasury) external onlyTreasury {
        futureTreasury = _treasury;
    }

    function acceptTreasury() external {
        require(msg.sender == futureTreasury, "only future treasury can access");
        treasury = futureTreasury;
        emit SetTreasury(futureTreasury);
    }

    function initialize(address _treasury) external initOnce {
        treasury = treasury;
        vestingExpiry = block.timestamp + 180 days;
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == treasury, "only treasury can access");
        _;
    }

    function delayEscrow() external onlyTreasury {
        require(vestingExpiry < block.timestamp + 90 days, "can only extend by 90 days");
        vestingExpiry = block.timestamp + 90 days;
    }

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external onlyTreasury {
        require(block.timestamp > vestingExpiry, "cannot access funds yet");
        IERC20(token).transfer(to, amount);
    }

    event SetTreasury(address indexed treasury);
} 
