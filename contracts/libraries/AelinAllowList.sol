// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library AelinAllowList {
    struct InitData {
        address[] allowListAddresses;
        uint256[] allowListAmounts;
    }

    struct AllowList {
        address[] allowListAddresses;
        uint256[] allowListAmounts;
        mapping(address => uint256) amountPerAddress;
        bool hasAllowList;
    }

    /**
     * @notice This function stores any Allow List information for a deal if there is any.
     * @param _init The Allow List information that is to be stored. This includes an array of 
     * addresses and an array of corresponding amounts that will be mapped together in storage.
     * @param _self The storage struct for the Allow List information.
     */
    function initialize(InitData calldata _init, AllowList storage _self) external {
        if (_init.allowListAddresses.length > 0 || _init.allowListAmounts.length > 0) {
            require(_init.allowListAddresses.length == _init.allowListAmounts.length, "arrays should be same length");
            _self.allowListAddresses = _init.allowListAddresses;
            _self.allowListAmounts = _init.allowListAmounts;
            for (uint256 i; i < _init.allowListAddresses.length; ++i) {
                _self.amountPerAddress[_init.allowListAddresses[i]] = _init.allowListAmounts[i];
            }
            _self.hasAllowList = true;
            emit AllowlistAddress(_init.allowListAddresses, _init.allowListAmounts);
        }
    }

    event AllowlistAddress(address[] indexed allowListAddresses, uint256[] allowlistAmounts);
}
