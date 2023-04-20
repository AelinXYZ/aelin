// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

contract MockPunks {
    mapping(uint => address) public punkIndexToAddress;

    mapping(address => uint256) public balanceOf;

    constructor() {}

    function mint(address _to, uint256 _tokenId) public virtual {
        balanceOf[_to] += 1;
        punkIndexToAddress[_tokenId] = _to;
    }
}
