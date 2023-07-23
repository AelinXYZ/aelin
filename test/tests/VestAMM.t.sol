// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestAMMUtils} from "./utils/VestAMMUtils.sol";
import {VestAMMFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import {VestAMM} from "contracts/VestAMM/VestAMM.sol";
import {CurveVestAMM} from "contracts/VestAMM/kinds/CurveVestAMM.sol";

contract VestAMMTest is VestAMMUtils {
    uint256 mainnetFork;

    IERC20 aelinToken;
    IERC20 daiToken;
    IERC20 aaveToken;
    IERC20 usdcToken;

    address user = address(0x000137);
    address investor = address(0x000138);
    address aelinCouncil = address(0x000420);

    VestAMMFactory factory;
    CurveVestAMM curveVestAMM;

    CurveVestAMM curveVestAMMInstance;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        aelinToken = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
        daiToken = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        aaveToken = IERC20(address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9));
        usdcToken = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));

        vm.deal(user, 1e12 ether);
        vm.deal(investor, 1e12 ether);
        vm.deal(aelinCouncil, 1e12 ether);

        factory = new VestAMMFactory(aelinCouncil);
        curveVestAMM = new CurveVestAMM();

        vm.startPrank(aelinCouncil);
        factory.addVestAMM(address(curveVestAMM));

        VAmmInfo memory info = getVAmmInfo(address(aaveToken), address(usdcToken), user);
        DealAccess memory access = getDealAccess();

        curveVestAMMInstance = CurveVestAMM(factory.createVestAMM(info, access, address(curveVestAMM)));
        vm.stopPrank();
    }

    function testTest() public {}
}
