// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/console.sol";
//import "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestAMMUtils} from "./utils/VestAMMUtils.sol";
import {VestAMMFactory} from "contracts/VestAMM/VestAMMFactory.sol";
import {VestAMM} from "contracts/VestAMM/VestAMM.sol";
import {BalancerVestAMM} from "contracts/VestAMM/kinds/BalancerVestAMM.sol";
import {CurveVestAMM} from "contracts/VestAMM/kinds/CurveVestAMM.sol";
import {SushiVestAMM} from "contracts/VestAMM/kinds/SushiVestAMM.sol";

/// @dev The tests here should all succeed against ANY vestAMM instance.
///      A seperate set of tests maybe (?) needed for AMM-specific instances.
contract VestAMMTest is VestAMMUtils {
    uint256 mainnetFork;

    IERC20 aelinToken;
    IERC20 daiToken;
    IERC20 aaveToken;
    IERC20 wETHToken;
    IERC20 usdcToken;

    address user = address(0x000137);
    address investor = address(0x000138);
    address aelinCouncil = address(0x000420);

    VestAMMFactory factory;

    //The VestAMM contract kinds added to the factory
    BalancerVestAMM balancerVestAMM;
    CurveVestAMM curveVestAMM;
    SushiVestAMM sushiVestAMM;

    //The VestAMM cloned instances cloned from the factory
    BalancerVestAMM balancerVestAMMInstance;
    CurveVestAMM curveVestAMMInstance;
    SushiVestAMM sushiVestAMMInstance;

    /// @dev used to randomly fuzz over vestAMM instances
    address[] public vestAMMInstancesArray = new address[](3);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        aelinToken = IERC20(address(0xa9C125BF4C8bB26f299c00969532B66732b1F758));
        daiToken = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        aaveToken = IERC20(address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9));
        wETHToken = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        usdcToken = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));

        vm.deal(user, 1e12 ether);
        vm.deal(investor, 1e12 ether);
        vm.deal(aelinCouncil, 1e12 ether);

        factory = new VestAMMFactory(aelinCouncil);

        balancerVestAMM = new BalancerVestAMM();
        curveVestAMM = new CurveVestAMM();
        sushiVestAMM = new SushiVestAMM();

        vm.startPrank(aelinCouncil);
        factory.addVestAMM(address(balancerVestAMM));
        factory.addVestAMM(address(curveVestAMM));
        factory.addVestAMM(address(sushiVestAMM));
        vm.stopPrank();

        vm.startPrank(user);
        /// @dev WETH Set as reward token, with only one SingleVestingSchedule
        //       Will need to build out better utils to allow for lots of different deal configurations
        VAmmInfo memory info = getVAmmInfo(address(aelinToken), address(usdcToken), user, address(wETHToken));
        DealAccess memory access = getDealAccess();

        balancerVestAMMInstance = BalancerVestAMM(factory.createVestAMM(info, access, address(balancerVestAMM)));
        curveVestAMMInstance = CurveVestAMM(factory.createVestAMM(info, access, address(curveVestAMM)));
        sushiVestAMMInstance = SushiVestAMM(factory.createVestAMM(info, access, address(sushiVestAMM)));
        vm.stopPrank();

        vestAMMInstancesArray = [
            address(balancerVestAMMInstance),
            address(curveVestAMMInstance),
            address(sushiVestAMMInstance)
        ];
    }

    /////////////
    // Deposit //
    /////////////

    function testFuzzDepositSingle(uint256 _seed, uint256 _amount) public {
        _amount = bound(_amount, 1, 1e18);

        VestAMM randomisedVestAMM = VestAMM(randomiseVestAMMInstance(vestAMMInstancesArray, _seed));

        vm.startPrank(user);

        //Use WETH as the reward token here
        (bool success, ) = address(wETHToken).call{value: _amount}("");
        require(success);
        uint256 wETHBalance = wETHToken.balanceOf(user);
        require(wETHBalance > 0);

        DepositToken[] memory depositSingle = new DepositToken[](1);
        depositSingle[0] = DepositToken(0, address(wETHToken), wETHBalance);

        wETHToken.approve(address(randomisedVestAMM), ~uint256(0));

        vm.expectEmit(true, true, true, true);
        emit SingleRewardDeposited(user, 0, address(wETHToken), wETHBalance);
        randomisedVestAMM.depositSingle(depositSingle);

        assertTrue(wETHToken.balanceOf(address(randomisedVestAMM)) == wETHBalance);
        assertTrue(randomisedVestAMM.holderDeposits(user, 0) == wETHBalance);
        assertFalse(randomisedVestAMM.depositComplete()); // Need to deposit Base

        vm.stopPrank();
    }
}
