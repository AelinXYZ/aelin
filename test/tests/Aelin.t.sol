// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Aelin} from "contracts/Aelin.sol";
import {AelinTestUtils} from "../utils/AelinTestUtils.sol";

contract AelinTest is Test, AelinTestUtils {
    Aelin public aelin;
    uint256 public immutable INITIAL_SUPPLY = 10 * 1e6 * 1e18;
    address public deployer = user1;
    address public minter = user2;

    error UnauthorizedMinter();
    error InvalidAddress();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event MinterAuthorized(address indexed minter);

    function setUp() public {
        vm.startPrank(deployer);
        aelin = new Aelin(aelinTreasury);
        aelin.setAuthorizedMinter(minter);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            Initialize
    //////////////////////////////////////////////////////////////*/

    function test_Initialize() public {
        assertEq(aelin.name(), "Aelin");
        assertEq(aelin.symbol(), "AELIN");
        assertEq(aelin.decimals(), 18);
        assertEq(aelin.totalSupply(), INITIAL_SUPPLY);
        assertEq(aelin.owner(), deployer);
        assertEq(aelin.balanceOf(aelinTreasury), INITIAL_SUPPLY);
    }

    /*//////////////////////////////////////////////////////////////
                            Mint()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Mint_RevertWhen_Unauthorized(address _minter) public {
        vm.assume(_minter != minter);
        vm.startPrank(_minter);
        vm.expectRevert(UnauthorizedMinter.selector);
        aelin.mint(_minter, 1);
        vm.stopPrank();
    }

    function testFuzz_Mint(uint256 _amount) public {
        uint256 boundedAmount = bound(_amount, 0, type(uint256).max - aelin.totalSupply());
        vm.startPrank(minter);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), minter, boundedAmount);
        aelin.mint(minter, boundedAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            Burn()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Burn(uint256 _amount) public {
        vm.assume(_amount <= INITIAL_SUPPLY);
        vm.startPrank(aelinTreasury);
        assertEq(aelin.balanceOf(aelinTreasury), INITIAL_SUPPLY);
        vm.expectEmit(true, true, false, true);
        emit Transfer(aelinTreasury, address(0), _amount);
        aelin.burn(_amount);
        assertEq(aelin.balanceOf(aelinTreasury), INITIAL_SUPPLY - _amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            SetAuthorizedMinter()
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SetAuthorizedMinter_RevertWhen_NotOwner(address _user, address _minter) public {
        vm.assume(_user != aelin.owner());
        vm.startPrank(_user);
        vm.expectRevert("Ownable: caller is not the owner");
        aelin.setAuthorizedMinter(_minter);
        vm.stopPrank();
    }

    function test_SetAuthorizedMinter_RevertWhen_InvalidAddress() public {
        vm.startPrank(deployer);
        vm.expectRevert(InvalidAddress.selector);
        aelin.setAuthorizedMinter(address(0));
        vm.stopPrank();
    }

    function test_SetAuthorizedMinter(address _minter) public {
        vm.assume(_minter != address(0));
        vm.assume(_minter != minter);
        vm.startPrank(deployer);
        assertEq(aelin.authorizedMinter(), minter);
        vm.expectEmit(true, false, false, false);
        emit MinterAuthorized(_minter);
        aelin.setAuthorizedMinter(_minter);
        assertEq(aelin.authorizedMinter(), _minter);
        vm.stopPrank();
    }
}
