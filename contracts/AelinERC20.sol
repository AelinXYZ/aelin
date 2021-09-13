// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// currently here to generate the abi, but eventually want to switch to it
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract AelinERC20 is ERC20 {    
    bool setInfo;
    mapping(address => mapping(address => uint256)) public _allowances;
    
    constructor () ERC20("", "") {}

    modifier initInfoOnce () {
        require(setInfo == false, "can only initialize once");
        _;
    }

    function _setNameAndSymbol(string memory _name, string memory _symbol) internal initInfoOnce returns (bool) {
        _name = _name;
        _symbol = _symbol;
        setInfo = true;
        return true;
    }

    function convertUnderlyingToAelinAmount(uint underlyingAmount, uint underlyingDecimals) internal view returns (uint) {
        return underlyingDecimals == decimals() ? 
            underlyingAmount :
            underlyingAmount * 10**(decimals()-underlyingDecimals);
    }

    function convertAelinToUnderlyingAmount(uint aelinTokenAmount, uint underlyingDecimals) internal view returns (uint) {
        return underlyingDecimals == decimals() ? 
            aelinTokenAmount :
            aelinTokenAmount / 10**(decimals()-underlyingDecimals);
    }
    
    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
    
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
