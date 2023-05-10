// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ICurvePool {
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts,
        bool use_eth,
        address receiver
    ) external;

    function calc_token_amount(uint256[2] memory _amounts) external view returns (uint256);

    function calc_withdraw_one_coin(uint256 token_amount, uint256 i) external view returns (uint256);

    function token() external view returns (address);

    function coins(uint index) external view returns (address);

    function fee() external view returns (uint256);

    struct CreateNewPool {
        string name;
        string symbol;
        address[2] tokens;
        uint256 A;
        uint256 gamma;
        uint256 mid_fee;
        uint256 out_fee;
        uint256 allowed_extra_profit;
        uint256 fee_gamma;
        uint256 adjustment_step;
        uint256 admin_fee;
        uint256 ma_half_time;
        uint256 initial_price;
    }
}
