// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// currently here to generate the abi, but eventually want to switch to it
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// @TODO extend standard ERC20 from Open Zeppelin
contract AelinERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    bool SET_INFO = false;
    
    uint public totalSupply = 0;
    
    mapping(address => mapping (address => uint)) public allowance;
    mapping(address => uint) public balanceOf;
    
    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint amount);

    /// @notice The standard EIP-20 approval event
    event Approval(address indexed owner, address indexed spender, uint amount);
    
    constructor () {}

    modifier initInfoOnce () {
        require(SET_INFO == false, "can only initialize once");
        _;
    }

    function _setNameAndSymbol(string memory _name, string memory _symbol) internal initInfoOnce returns (bool) {
        name = _name;
        symbol = _symbol;
        SET_INFO = true;
        return true;
    }
    
    function _mint(address dst, uint amount) internal {
        totalSupply += amount;
        balanceOf[dst] += amount;
        emit Transfer(address(0), dst, amount);
    }
    
    function _burn(address from, uint amount) internal {
        totalSupply -= amount;
        balanceOf[from] -= amount;
        require(balanceOf[from] >= 0, "balance cant be negative");
        require(totalSupply >= 0, "cant burn more than supply");
        emit Transfer(from, address(0), amount);
    }

    function convertUnderlyingToAelinAmount(uint underlyingAmount, uint underlyingDecimals) pure internal returns (uint) {
        return underlyingAmount * 10**(18-underlyingDecimals);
    }

    function convertAelinToUnderlyingAmount(uint aelinTokenAmount, uint underlyingDecimals) pure internal returns (uint) {
        return aelinTokenAmount / 10**(18-underlyingDecimals);
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address dst, uint amount) external virtual returns (bool) {
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    function transferFrom(address src, address dst, uint amount) external virtual returns (bool) {
        address spender = msg.sender;
        uint spenderAllowance = allowance[src][spender];

        if (spender != src && spenderAllowance != type(uint).max) {
            uint newAllowance = spenderAllowance - amount;
            allowance[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    function _transferTokens(address src, address dst, uint amount) internal virtual {
        balanceOf[src] -= amount;
        balanceOf[dst] += amount;
        // @NOTE I added this here as a security measure although not sure it is needed.
        require(balanceOf[src] >= 0, "balance cant be negative");
        
        emit Transfer(src, dst, amount);
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
