// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "contracts/libraries/MerkleTree.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AelinVestAMMTest is Test {
    uint256 mainnetFork;

    IERC20 aelinToken = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
    IERC20 daiToken = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    IERC20 aaveToken = IERC20(address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9));
    IERC20 usdcToken = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    address user = address(0x000137);
    address investor = address(0x000138);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        //
    }
}
