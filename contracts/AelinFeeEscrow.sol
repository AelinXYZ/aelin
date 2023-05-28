// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinFeeEscrow {
    using SafeERC20 for IERC20;

    uint256 public constant VESTING_PERIOD = 0 days;
    uint256 public constant DELAY_PERIOD = 90 days;

    uint256 public vestingExpiry;
    address public treasury;
    address public futureTreasury;
    address public escrowedToken;

    bool private calledInitialize;

    function initialize(address _treasury, address _escrowedToken) external initOnce {
        treasury = _treasury;
        vestingExpiry = block.timestamp + VESTING_PERIOD;
        escrowedToken = _escrowedToken;
        emit InitializeEscrow(msg.sender, _treasury, vestingExpiry, escrowedToken);
    }

    /**
     * @notice This function allows the treasury to set a future treasury address without changing the
     * treasury address currently.
     * @param _futureTreasury The future treasury address.
     */
    function setTreasury(address _futureTreasury) external onlyTreasury {
        require(_futureTreasury != address(0), "cant pass null treasury address");
        futureTreasury = _futureTreasury;
    }

    /**
     * @notice This function allows the future treasury address to replace the current treasury address.
     */
    function acceptTreasury() external {
        require(msg.sender == futureTreasury, "must be future treasury");
        treasury = futureTreasury;
        emit SetTreasury(futureTreasury);
    }

    /**
     * @notice This function allows the treasury to further delay the vesting expiry of escrowed assets
     * by the DELAY_PERIOD.
     */
    function delayEscrow() external onlyTreasury {
        vestingExpiry = block.timestamp + DELAY_PERIOD;
        emit DelayEscrow(vestingExpiry);
    }

    /**
     * @notice This function allows the treasury to transfer all of the escrow tokens to the treasury.
     */
    function withdrawToken() external onlyTreasury {
        require(block.timestamp > vestingExpiry, "cannot access funds yet");
        uint256 balance = IERC20(escrowedToken).balanceOf(address(this));
        IERC20(escrowedToken).safeTransfer(treasury, balance);
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == treasury, "must be treasury");
        _;
    }

    event SetTreasury(address indexed treasury);
    event InitializeEscrow(
        address indexed dealAddress,
        address indexed treasury,
        uint256 vestingExpiry,
        address indexed escrowedToken
    );
    event DelayEscrow(uint256 vestingExpiry);
}
