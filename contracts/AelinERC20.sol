// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/**
 * @dev a standard ERC20 contract that is extended with a few methods
 * described in detail below
 */
contract AelinERC20 is ERC20 {
    bool setInfo;
    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol in the initializer which requires these custom variables
    */
    string private _custom_name;
    string private _custom_symbol;

    constructor() ERC20("", "") {}

    modifier initInfoOnce() {
        require(setInfo == false, "can only initialize once");
        _;
    }

    /**
     * @dev Due to the constructor being empty for the MinimalProxy architecture we need
     * to set the name and symbol in the initializer which requires this custom logic
     * for name(), symbol(), and _setNameAndSymbol()
     */
    function name() public view virtual override returns (string memory) {
        return _custom_name;
    }

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

    /**
     * @dev Due to the 4 tokens in the Aelin protocol:
     * purchase token, pool token, deal token, and underlying deal token,
     * we need 2 methods to convert back and forth between tokens of varying decimals 
     */
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

    /**
     * @dev Add this to prevent reentrancy attacks on purchasePoolTokens and depositUnderlying
     * source: https://quantstamp.com/blog/how-the-dforce-hacker-used-reentrancy-to-steal-25-million
     * uniswap implementation: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L31-L36
     */
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'AelinV1: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
}
