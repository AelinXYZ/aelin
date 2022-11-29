// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

contract VestAMMFeeModule {
    bool private calledInitialize;

    /**
     * @dev the constructor will always be blank due to the MinimalProxyFactory pattern
     * this allows the underlying logic of this contract to only be deployed once
     * and each new escrow created is simply a storage wrapper
     */
    constructor() {}

    function initialize() external initOnce {}

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    // callable for each locked LP whose amounts are tracked as a % of total stakers each week
    function claimFees() external {}
}
