// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../libraries/AelinNftGating.sol";
import "../../libraries/AelinAllowList.sol";

interface IVestAMMLibrary {
    function deployPool() external view returns (bool);

    function addLiquidity(uint256, uint256) external view returns (bool);

    function removeLiquidity(uint256, uint256) external view returns (bool);
}
