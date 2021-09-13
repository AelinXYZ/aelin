// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// currently here to generate the abi, but eventually want to switch to it
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract AelinERC20 is ERC20 {
    bool setInfo;
    mapping(address => mapping(address => uint256)) public _allowances;
    string private _custom_name;
    string private _custom_symbol;

    constructor() ERC20("", "") {}

    modifier initInfoOnce() {
        require(setInfo == false, "can only initialize once");
        _;
    }

    function name() public view virtual override returns (string memory) {
        return _custom_name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _custom_symbol;
    }

    function _setNameAndSymbol(string memory _name, string memory _symbol)
        internal
        initInfoOnce
        returns (bool)
    {
        _custom_name = _name;
        _custom_symbol = _symbol;
        setInfo = true;
        return true;
    }

    function convertUnderlyingToAelinAmount(
        uint256 underlyingAmount,
        uint256 underlyingDecimals
    ) internal view returns (uint256) {
        return
            underlyingDecimals == decimals()
                ? underlyingAmount
                : underlyingAmount * 10**(decimals() - underlyingDecimals);
    }

    function convertAelinToUnderlyingAmount(
        uint256 aelinTokenAmount,
        uint256 underlyingDecimals
    ) internal view returns (uint256) {
        return
            underlyingDecimals == decimals()
                ? aelinTokenAmount
                : aelinTokenAmount / 10**(decimals() - underlyingDecimals);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            )
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
