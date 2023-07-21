// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ICurvePool {
    function add_liquidity(uint256[2] memory, uint256) external returns (uint256);

    function remove_liquidity(uint256, uint256[2] memory) external;

    function calc_token_amount(uint256[2] memory) external view returns (uint256);

    function calc_withdraw_one_coin(uint256, uint256) external view returns (uint256);

    function token() external view returns (address);

    function coins(uint) external view returns (address);

    function fee() external view returns (uint256);

    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
}
