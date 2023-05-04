// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ICryptoPunks {
    function balanceOf(address) external view returns (uint256);

    function punkIndexToAddress(uint256) external view returns (address);
}
