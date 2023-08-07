// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {VestAMM} from "./VestAMM.sol";
import {AelinFeeModule} from "./AelinFeeModule.sol";
import {AelinNftGating} from "../libraries/AelinNftGating.sol";
import {AelinAllowList} from "../libraries/AelinAllowList.sol";
import {IVestAMM} from "./interfaces/IVestAMM.sol";
import {VestAMMRegistry} from "./VestAMMRegistry.sol";

contract VestAMMFactory is IVestAMM, VestAMMRegistry {
    address public immutable AELIN_FEE_MODULE;

    /// @dev fix later if keeping
    address public immutable AELIN_MULTI_REWARDS = address(420);
    address public immutable VEST_DAO_FEES = 0x0000000000000000000000000000000000000000;

    constructor(address _aelinCouncil) VestAMMRegistry(_aelinCouncil) {
        AELIN_FEE_MODULE = address(new AelinFeeModule());
    }

    /**
     * @param _vAmmInfo all the info related to the VestAMM instance (vAMM)
     * @param _dealAccess all the data needed to know who can access the vAMM instance
     */
    function createVestAMM(
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess,
        address _vestAMMInstance
    ) external returns (address vAmmAddress) {
        require(vestAMMExists[_vestAMMInstance], "Invalid AMM");

        vAmmAddress = Clones.clone(_vestAMMInstance);

        /// @dev storage for the deployed vestAMM instances?

        VestAMM(vAmmAddress).initialize(_vAmmInfo, _dealAccess, AELIN_FEE_MODULE, AELIN_MULTI_REWARDS);

        // TODO
        // emit NewVestAMM(_vAmmInfo, _dealAccess);
    }
}
