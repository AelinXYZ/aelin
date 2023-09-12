// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error ZeroAddress();
error ZeroAmount();
error WithdrawWindowClosed();
error NoSwapNFT();
error NftNotSet();
error NftAlreadySet();

contract AelinBurner is Ownable {
    using SafeERC20 for IERC20;

    uint256 public immutable start;

    uint256 public constant AELIN_SUPPLY = 2196874238168313483771;
    uint256 public constant USDC_SUPPLY = 747739907449;
    uint256 public constant VEKWENTA_SUPPLY = 629992504160932582911;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant AELIN = 0x61BAADcF22d2565B0F471b291C475db5555e0b76;
    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant VEKWENTA = 0x678d8f4Ba8DFE6bad51796351824DcCECeAefF2B;

    uint256 public constant WITHDRAW_WINDOW = 1 weeks;

    address public swapNFT;

    constructor() {
        start = block.timestamp;
    }

    function setNft(address _swapNFT) external onlyOwner {
        if (swapNFT != address(0)) revert NftAlreadySet();
        if (_swapNFT == address(0)) revert ZeroAddress();
        swapNFT = _swapNFT;
    }

    function burn(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();
        if (swapNFT == address(0)) revert NftNotSet();
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

    function getSwapAmount(uint256 _amount) public pure returns (uint256, uint256) {
        return (_amount * USDC_SUPPLY / AELIN_SUPPLY, _amount * VEKWENTA_SUPPLY / AELIN_SUPPLY);
    }

    event TokenSwapped(address indexed sender, uint256 aelinAmount, uint256 usdcAmount, uint256 veKwentaAmount);
}
