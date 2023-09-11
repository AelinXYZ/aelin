// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error ZeroAddress();
error ZeroAmount();
error WithdrawWindowClosed();
error NoSwapNFT();
error AlreadyDeposited();

contract AelinBurner is Ownable {
    using SafeERC20 for IERC20;

    uint256 public immutable aelinSupply;
    address public immutable swapNFT;
    uint256 public immutable start;

    uint256 public usdcSupply;
    uint256 public veKwentaSupply;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public constant AELIN = 0x61BAADcF22d2565B0F471b291C475db5555e0b76;
    address public constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant VEKWENTA = 0x678d8f4Ba8DFE6bad51796351824DcCECeAefF2B;

    uint256 public constant WITHDRAW_WINDOW = 4 weeks;

    bool public deposited;

    constructor(uint256 _aelinSupply, address _swapNFT) {
        if (_aelinSupply == 0) revert ZeroAmount();
        if (_swapNFT == address(0)) revert ZeroAddress();
        aelinSupply = _aelinSupply;
        swapNFT = _swapNFT;
        start = block.timestamp;
    }

    function depositTokens() external onlyOwner {
        if (deposited) revert AlreadyDeposited();

        uint256 usdcBalance = IERC20(USDC).balanceOf(owner());
        uint256 veKwentaBalance = IERC20(VEKWENTA).balanceOf(owner());

        IERC20(USDC).safeTransferFrom(owner(), address(this), usdcBalance);
        IERC20(VEKWENTA).safeTransferFrom(owner(), address(this), veKwentaBalance);

        usdcSupply = usdcBalance;
        veKwentaSupply = veKwentaBalance;
        deposited = true;
    }

    function getSwapAmount(uint256 _amount) public view returns (uint256, uint256) {
        uint256 share = _amount / aelinSupply;
        return (share * usdcSupply, share * veKwentaSupply);
    }

    function burn(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();
        if (IERC721(swapNFT).balanceOf(msg.sender) == 0) revert NoSwapNFT();

        (uint256 usdcAmount, uint256 veKwentaAmount) = getSwapAmount(_amount);

        emit TokenSwapped(msg.sender, _amount, usdcAmount, veKwentaAmount);

        IERC20(AELIN).safeTransferFrom(msg.sender, BURN_ADDRESS, _amount);
        IERC20(USDC).safeTransfer(msg.sender, usdcAmount);
        IERC20(VEKWENTA).safeTransfer(msg.sender, veKwentaAmount);
    }

    function withdraw(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (block.timestamp > start + WITHDRAW_WINDOW) revert WithdrawWindowClosed();

        IERC20(_token).safeTransfer(owner(), _amount);
    }

    event TokenSwapped(address indexed sender, uint256 aelinAmount, uint256 usdcAmount, uint256 veKwentaAmount);
}
