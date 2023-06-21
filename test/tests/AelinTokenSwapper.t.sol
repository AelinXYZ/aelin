// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Aelin} from "contracts/Aelin.sol";
import {AelinTokenSwapper} from "contracts/AelinTokenSwapper.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AelinTokenSwapperTest is Test, AelinTestUtils {
    IERC20 public oldToken;
    Aelin public newToken;
    AelinTokenSwapper public aelinTokenSwapper;

    uint256 public immutable TOKEN_SUPPLY = 10 * 1e6 * 1e18;
    uint256 public immutable OLD_TOKEN_SUPPLY = 5000 * 1e18;

    address public deployer = user1;
    address public minter = user2;

    error BalanceTooLow();
    error AmountTooLow();
    error Unauthorized();
    error AwaitingDeposit();
    error AlreadyDeposited();

    event TokenDeposited(address indexed sender, uint256 amount);
    event TokenSwapped(address indexed sender, uint256 depositAmount, uint256 swapAmount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        vm.startPrank(deployer);
        oldToken = new ERC20("oldAelin", "AELIN");
        newToken = new Aelin(aelinTreasury);
        aelinTokenSwapper = new AelinTokenSwapper(address(newToken), address(oldToken), aelinTreasury);
        deal(address(oldToken), aelinTreasury, OLD_TOKEN_SUPPLY);
        deal(address(newToken), aelinTreasury, TOKEN_SUPPLY);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            Initialize
    //////////////////////////////////////////////////////////////*/

    function test_Initialize() public {
        assertEq(aelinTokenSwapper.aelinToken(), address(newToken));
        assertEq(aelinTokenSwapper.oldAelinToken(), address(oldToken));
        assertEq(aelinTokenSwapper.deposited(), false);
        assertEq(aelinTokenSwapper.aelinTreasury(), aelinTreasury);
        assertEq(IERC20(address(newToken)).balanceOf(address(aelinTokenSwapper)), 0);
        assertEq(IERC20(address(oldToken)).balanceOf(address(aelinTokenSwapper)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            DepositTokens()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositTokens_RevertWhen_NotTreasury(address _depositor) public {
        vm.assume(_depositor != aelinTreasury);
        vm.startPrank(_depositor);
        vm.expectRevert(Unauthorized.selector);
        aelinTokenSwapper.depositTokens();
        vm.stopPrank();
    }

    function testFuzz_DepositTokens_RevertWhen_BalanceTooLow(uint256 _burnAmount) public {
        vm.startPrank(aelinTreasury);
        uint256 initialBalance = newToken.balanceOf(aelinTreasury);
        vm.assume(_burnAmount > 0);
        vm.assume(_burnAmount <= initialBalance);

        newToken.burn(_burnAmount);
        assertEq(newToken.balanceOf(aelinTreasury), initialBalance - _burnAmount);

        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        aelinTokenSwapper.depositTokens();
        vm.stopPrank();
    }

    function test_DepositTokens() public {
        vm.startPrank(aelinTreasury);

        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);

        vm.expectEmit(true, true, false, true);
        emit Transfer(aelinTreasury, address(aelinTokenSwapper), TOKEN_SUPPLY);
        vm.expectEmit(true, true, false, true);
        emit TokenDeposited(aelinTreasury, TOKEN_SUPPLY);
        aelinTokenSwapper.depositTokens();

        assertEq(newToken.balanceOf(aelinTreasury), 0);
        assertEq(newToken.balanceOf(address(aelinTokenSwapper)), TOKEN_SUPPLY);
        assertEq(aelinTokenSwapper.deposited(), true);

        // we make sure we can't deposit twice
        vm.expectRevert(AlreadyDeposited.selector);
        aelinTokenSwapper.depositTokens();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            Swap()
    //////////////////////////////////////////////////////////////*/

    function test_Swap_RevertWhen_NoDeposit() public {
        vm.expectRevert(AwaitingDeposit.selector);
        aelinTokenSwapper.swap(0);
    }

    function test_Swap_RevertWhen_AmountTooLow() public {
        vm.startPrank(aelinTreasury);
        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);
        aelinTokenSwapper.depositTokens();
        vm.expectRevert(AmountTooLow.selector);
        aelinTokenSwapper.swap(0);
        vm.stopPrank();
    }

    function testFuzz_Swap_RevertWhen_BalanceTooLow(uint256 _amount) public {
        vm.assume(_amount > oldToken.balanceOf(aelinTreasury));
        vm.startPrank(aelinTreasury);
        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);
        aelinTokenSwapper.depositTokens();
        vm.expectRevert(BalanceTooLow.selector);
        aelinTokenSwapper.swap(_amount);
        vm.stopPrank();
    }

    function test_Swap_All() public {
        vm.startPrank(aelinTreasury);

        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);
        aelinTokenSwapper.depositTokens();
        assertEq(aelinTokenSwapper.deposited(), true);

        oldToken.approve(address(aelinTokenSwapper), OLD_TOKEN_SUPPLY);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(aelinTokenSwapper), aelinTreasury, TOKEN_SUPPLY);
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(aelinTreasury, OLD_TOKEN_SUPPLY, TOKEN_SUPPLY);
        aelinTokenSwapper.swap(OLD_TOKEN_SUPPLY);

        assertEq(newToken.balanceOf(aelinTreasury), TOKEN_SUPPLY);
        assertEq(newToken.balanceOf(address(aelinTokenSwapper)), 0);
        assertEq(oldToken.balanceOf(aelinTreasury), 0);
        assertEq(oldToken.balanceOf(address(aelinTokenSwapper)), OLD_TOKEN_SUPPLY);

        vm.stopPrank();
    }

    function testFuzz_Swap(uint256 _amount1, uint256 _amount2, uint256 _amount3) public {
        vm.assume(_amount1 > 1);
        vm.assume(_amount2 > 1);
        vm.assume(_amount3 > 1);
        vm.assume(_amount1 < OLD_TOKEN_SUPPLY);
        vm.assume(_amount2 < OLD_TOKEN_SUPPLY);
        vm.assume(_amount3 < OLD_TOKEN_SUPPLY);

        vm.assume(_amount1 + _amount2 + _amount3 < OLD_TOKEN_SUPPLY);
        vm.startPrank(aelinTreasury);

        assertEq(oldToken.balanceOf(address(0x111)), 0);
        assertEq(oldToken.balanceOf(address(0x222)), 0);
        assertEq(oldToken.balanceOf(address(0x333)), 0);

        assertEq(newToken.balanceOf(address(0x111)), 0);
        assertEq(newToken.balanceOf(address(0x222)), 0);
        assertEq(newToken.balanceOf(address(0x333)), 0);

        // Treasury distributes tokens to 3 addresses
        oldToken.transfer(address(0x111), _amount1);
        oldToken.transfer(address(0x222), _amount2);
        oldToken.transfer(address(0x333), _amount3);

        assertEq(oldToken.balanceOf(address(0x111)), _amount1);
        assertEq(oldToken.balanceOf(address(0x222)), _amount2);
        assertEq(oldToken.balanceOf(address(0x333)), _amount3);

        newToken.approve(address(aelinTokenSwapper), TOKEN_SUPPLY);
        aelinTokenSwapper.depositTokens();
        assertEq(aelinTokenSwapper.deposited(), true);
        vm.stopPrank();

        // Address 0x111 swaps all their tokens
        vm.startPrank(address(0x111));
        oldToken.approve(address(aelinTokenSwapper), _amount1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(aelinTokenSwapper), address(0x111), _amount1 * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(address(0x111), _amount1, _amount1 * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        aelinTokenSwapper.swap(_amount1);
        vm.stopPrank();

        // Address 0x222 swaps all their tokens
        vm.startPrank(address(0x222));
        oldToken.approve(address(aelinTokenSwapper), _amount2);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(aelinTokenSwapper), address(0x222), _amount2 * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(address(0x222), _amount2, _amount2 * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        aelinTokenSwapper.swap(_amount2);
        vm.stopPrank();

        // Address 0x333 swaps half of their tokens
        vm.startPrank(address(0x333));
        oldToken.approve(address(aelinTokenSwapper), _amount3);
        uint256 halfAmount = _amount3 / 2;
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(aelinTokenSwapper), address(0x333), halfAmount * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(address(0x333), halfAmount, halfAmount * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        aelinTokenSwapper.swap(halfAmount);

        assertEq(newToken.balanceOf(address(0x333)), halfAmount * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        assertEq(oldToken.balanceOf(address(0x333)), _amount3 - halfAmount);

        // Address 0x333 swaps the rest of their tokens
        vm.expectEmit(true, true, false, true);
        emit Transfer(
            address(aelinTokenSwapper),
            address(0x333),
            (_amount3 - halfAmount) * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY)
        );
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(
            address(0x333),
            (_amount3 - halfAmount),
            (_amount3 - halfAmount) * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY)
        );
        aelinTokenSwapper.swap(_amount3 - halfAmount);

        assertEq(
            newToken.balanceOf(address(aelinTokenSwapper)),
            (OLD_TOKEN_SUPPLY - _amount1 - _amount2 - _amount3) * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY)
        );
        assertEq(oldToken.balanceOf(address(aelinTokenSwapper)), _amount1 + _amount2 + _amount3);
        vm.stopPrank();

        // Finally, treasury swaps all its tokens
        vm.startPrank(aelinTreasury);
        oldToken.approve(address(aelinTokenSwapper), OLD_TOKEN_SUPPLY);
        vm.expectEmit(true, true, false, true);
        uint256 treasuryBalance = OLD_TOKEN_SUPPLY - _amount1 - _amount2 - _amount3;
        assertEq(oldToken.balanceOf(aelinTreasury), treasuryBalance);
        emit Transfer(address(aelinTokenSwapper), aelinTreasury, (treasuryBalance) * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        vm.expectEmit(true, false, false, true);
        emit TokenSwapped(aelinTreasury, treasuryBalance, treasuryBalance * (TOKEN_SUPPLY / OLD_TOKEN_SUPPLY));
        aelinTokenSwapper.swap(treasuryBalance);

        // Post-swap checks
        assertEq(newToken.balanceOf(address(aelinTokenSwapper)), 0);
        assertEq(newToken.balanceOf(address(0x111)), (_amount1 * TOKEN_SUPPLY) / OLD_TOKEN_SUPPLY);
        assertEq(newToken.balanceOf(address(0x222)), (_amount2 * TOKEN_SUPPLY) / OLD_TOKEN_SUPPLY);
        assertEq(newToken.balanceOf(address(0x333)), (_amount3 * TOKEN_SUPPLY) / OLD_TOKEN_SUPPLY);
        assertEq(
            newToken.balanceOf(aelinTreasury),
            ((OLD_TOKEN_SUPPLY - _amount1 - _amount2 - _amount3) * TOKEN_SUPPLY) / OLD_TOKEN_SUPPLY
        );

        assertEq(oldToken.balanceOf(address(aelinTokenSwapper)), OLD_TOKEN_SUPPLY);
        assertEq(oldToken.balanceOf(address(0x111)), 0);
        assertEq(oldToken.balanceOf(address(0x222)), 0);
        assertEq(oldToken.balanceOf(address(0x333)), 0);
        assertEq(oldToken.balanceOf(aelinTreasury), 0);

        vm.stopPrank();
    }
}
