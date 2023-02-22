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
        for (uint256 i; i < _vAmmInfo.vestingSchedule.length; ++i) {
            require(1825 days >= _vAmmInfo.vestingSchedule[i].vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _vAmmInfo.vestingSchedule[i].vestingPeriod, "max 5 year vesting");
            require(100 * 10**18 >= _vAmmInfo.vestingSchedule[i].investorShare, "max 100% to investor");
            require(0 <= _vAmmInfo.vestingSchedule[i].investorShare, "min 0% to investor");
            require(0 < _vAmmInfo.vestingSchedule[i].totalHolderTokens, "allocate tokens to schedule");
            require(_vAmmInfo.vestingSchedule[i].purchaseTokenPerDealToken > 0, "invalid deal price");
        }

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

    // TODO a function that locks existing LP tokens
    // or takes single sided tokens and LPs them, selling a % in the process
    // to the other asset before LP'ing in exchange for single sided rewards
    // which may be locked on a vesting schedule
    function lockLiquidity() {}
}
