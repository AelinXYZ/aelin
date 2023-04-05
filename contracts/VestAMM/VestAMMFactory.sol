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

    // MAJOR TODO list
    // TODO change errors to use Custom structs
    // TODO add in a curve multi rewards contract to the VestAMM so that you can distribute protocol fees to holders
    // NOTE can we do this without any restrictions on the amount of rewards tokens since it loops through an array
    // TODO write initial tests that checks the ability to start a vAMM and deposit base and single reward tokens to start the acceptDeal window
    // TODO triple check all arguments start with _, casing is correct. well commented in the natspec format, etc
    // TODO create a pool and add liquidity on Balancer
    // TODO finish the create liquidity methods on the vest amm contracts
    // TODO finish the claiming logic and make the math is all correct
    // TODO finish the fee claiming of swap fees and figure out how to integrated it
    // TODO finish the withdraw methods like depositorWithdraw and depositorDeallocWithdraw which will handle edge cases such as deallocation or when the deal is cancelled
    // or when someone puts too many funds into a contract
    // TODO (future) make sure the logic works with 80/20 balancer pools and not just when its 50/50
    function createVestAMM(
        AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess
    ) external returns (address vAmmAddress) {
        require(AELIN_LIBRARY_LIST.libraryList[_ammData.ammLibrary], "invalid AMM library");

        vAmmAddress = Clones.clone(VEST_AMM_LOGIC);

        VestAMM(vAmmAddress).initialize(_ammData, _vAmmInfo, _singleRewards, _dealAccess, AELIN_FEE_MODULE);

        emit NewVestAMM(_ammData, _vAmmInfo, _singleRewards, _dealAccess);
    }

    // TODO a function that locks existing LP tokens
    // or takes single sided tokens and LPs them, selling a % in the process
    // to the other asset before LP'ing in exchange for single sided rewards
    // which may be locked on a vesting schedule
    function lockLiquidity() external {}
}
