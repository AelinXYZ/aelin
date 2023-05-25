// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {IVestAMMLibrary} from "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";
import {IVestAMM} from "contracts/VestAMM/interfaces/IVestAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

// This contract is used to test the VestAMMLibrary functions
contract VestAMMLibrary {
    IVestAMMLibrary public vestAMMLibrary;

    constructor(address _lib) {
        vestAMMLibrary = IVestAMMLibrary(_lib);
    }

    function deployPool(IVestAMMLibrary.CreateNewPool calldata _newPool) public returns (address) {
        IERC20(_newPool.tokens[0]).approve(address(vestAMMLibrary), type(uint256).max);
        IERC20(_newPool.tokens[1]).approve(address(vestAMMLibrary), type(uint256).max);
        return vestAMMLibrary.deployPool(_newPool);
    }

    function addInitialLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return vestAMMLibrary.addInitialLiquidity(_addLiquidityData);
    }

    function addLiquidity(IVestAMMLibrary.AddLiquidity calldata _addLiquidityData)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return vestAMMLibrary.addLiquidity(_addLiquidityData);
    }

    function removeLiquidity(IVestAMMLibrary.RemoveLiquidity calldata _removeLiquidityData)
        external
        returns (uint256, uint256)
    {
        IERC20(_removeLiquidityData.lpToken).approve(address(vestAMMLibrary), _removeLiquidityData.lpTokenAmtIn);
        return vestAMMLibrary.removeLiquidity(_removeLiquidityData);
    }

    function checkPoolExists(IVestAMM.VAmmInfo calldata _vammInfo) external view returns (bool) {
        return vestAMMLibrary.checkPoolExists(_vammInfo);
    }
}
