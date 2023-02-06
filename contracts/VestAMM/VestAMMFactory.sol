// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./VestAMM.sol";
import "./VestAMMFeeModule.sol";
import "../libraries/AelinNftGating.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../libraries/AelinAllowList.sol";
import {IVestAMM} from "./interfaces/IVestAMM.sol";

contract VestAMMDealFactory is IVestAMM {
    using SafeERC20 for IERC20;

    address public immutable VEST_AMM_LOGIC;
    address public immutable VEST_AMM_FEE_MODULE;
    address public immutable VEST_DAO_FEES = 0x0000000000000000000000000000000000000000;

    constructor() {
        VEST_AMM_LOGIC = address(new VestAMM());
        VEST_AMM_FEE_MODULE = address(new VestAMMFeeModule());
    }

    function createVestAMM(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess
    ) external returns (address vestAddress) {
        vestAddress = Clones.clone(VEST_AMM_LOGIC);

        VestAMM(vestAddress).initialize(
            _ammData,
            _vAmmInfo,
            _singleRewards,
            _dealAccess,
            VEST_AMM_FEE_MODULE,
            VEST_DAO_FEES
        );

        emit NewVestAMM(_ammData, _vAmmInfo, _singleRewards, _dealAccess);
    }
}
