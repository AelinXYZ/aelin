// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../interfaces/IVestAMMLibrary.sol";

library CurveVestAMM is IVestAMMLibrary {

    function addLiquidity() external {
        expected = pool.calc_token_amount([1e18, 1e18], true) * 0.99

        pool.add_liquidity([1e18, 1e18], expected, {'from': alice})
    }

    function removeLiquidity() external {
        // ...
    }

}