// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./VestAMM.sol";
import "./AelinFeeModule.sol";
import "../libraries/AelinNftGating.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../libraries/AelinAllowList.sol";
import {IVestAMM} from "./interfaces/IVestAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestAMMDealFactory is IVestAMM {
    using SafeERC20 for IERC20;

    address public immutable VEST_AMM_LOGIC;
    address public immutable AELIN_FEE_MODULE;
    address public immutable VEST_DAO_FEES = 0x0000000000000000000000000000000000000000;
    address public immutable AELIN_LIBRARY_LIST;

    constructor(address _aelinLibraryList) {
        VEST_AMM_LOGIC = address(new VestAMM());
        AELIN_FEE_MODULE = address(new AelinFeeModule());
        AELIN_LIBRARY_LIST = _aelinLibraryList;
    }

    // TODO list
    // TODO add a function to libraries which allows us to collect external rewards e.g. Balancer weekly rewards and distributes them to holders via the Multi Rewards Distributor we are adding
    // TODO add in a curve multi rewards contract to the VestAMM so that you can distribute protocol fees to holders
    // NOTE that instead of staking token you will simply fake stake the number of investment tokens that you accepted the deal with
    // TODO write initial tests that checks the ability to start a vAMM and deposit base and single reward tokens to start the acceptDeal window
    // NOTE the contracts must compile first
    // TODO triple check all arguments start with _, casing is correct. well commented in the natspec format, etc
    // TODO finish the Aelin protocol fee claiming of swap fees and reinvest the remaining back to the LP for locked investors
    // TODO finish the depositorDeallocWithdraw method after the lp is funded if there is excess interest in the pool
    // TODO (future) make sure the logic works with 80/20 balancer pools and not just when its 50/50
    // TODO on a liquidity growth round we probably want to let existing LPs migrate their current positions and lock them for rewards
    // TODO first validate the AMM data
    // TODO finish the create liquidity methods on the vest amm contracts
    // NOTE for liquidity launch we are pretty close but we need to fix the way we capture fees for single rewards
    // NOTE for liquidity growth...
    function createVestAMM(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess
    ) external returns (address vAmmAddress) {
        require(AELIN_LIBRARY_LIST.libraryList[_ammData.ammLibrary], "invalid AMM library");

        vAmmAddress = Clones.clone(VEST_AMM_LOGIC);

        VestAMM(vAmmAddress).initialize(_ammData, _vAmmInfo, _dealAccess, AELIN_FEE_MODULE);

        emit NewVestAMM(_ammData, _vAmmInfo, _dealAccess);
    }

    // TODO a function that locks existing LP tokens
    // or takes single sided tokens and LPs them, selling a % in the process
    // to the other asset before LP'ing in exchange for single sided rewards
    // which may be locked on a vesting schedule
    function lockLiquidity() external {}
}
