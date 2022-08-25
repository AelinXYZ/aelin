// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AelinUnderlyingDealToken is ERC20 {
		constructor(address _aelinDealAddress, uint256 _dealAmount, address _account, uint256 _transferAmount, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
				require(_aelinDealAddress != address(0) || _account != address(0), "Cannot create token if both deal and account addresses are null");
				if(_aelinDealAddress != address(0)) {
					_mint(_aelinDealAddress, _dealAmount);
				}
				if (_account != address(0)) {
					_mint(_account, _transferAmount);
				}
    }
}
