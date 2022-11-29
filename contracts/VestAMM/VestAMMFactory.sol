// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../MinimalProxyFactory.sol";
import "./VestAMM.sol";
import "./VestAMMFeeModule.sol";
import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import {IVestAMM} from "./interfaces/IVestAMM.sol";

contract VestAMMDealFactory is MinimalProxyFactory, IVestAMM {
    using SafeERC20 for IERC20;

    address public immutable VEST_AMM_LOGIC;
    address public immutable VEST_AMM_FEE_MODULE;

    constructor(address _vestAMMFeeModule) {
        VEST_AMM_LOGIC = address(new VestAMM());
        VEST_AMM_FEE_MODULE = address(new VestAMMFeeModule());
    }

    function createVestAMM(
        AMMData calldata _ammData,
        LiquidityLaunch calldata _liquidityLaunch,
        SingleRewardConfig[] calldata _singleRewards,
        DealAccess calldata _dealAccess
    ) external returns (address vestAddress) {
        vestAddress = _cloneAsMinimalProxy(VEST_AMM_LOGIC, "Could not create new deal");

        VestAMM(vestAddress).initialize(_ammData, _liquidityLaunch, _dealAccess, _singleRewards, VEST_AMM_FEE_MODULE);

        emit NewVestAMM(_ammData, _liquidityLaunch, _dealAccess, _singleRewards);
    }
}

// so you have a single contract that holds all the LP tokens for the pool?
// then you have individual vesting contracts per user that are tied to unlocking these LP units
// when you LP during the launch phase then you create a vesting entry that starts at the end of the deposit window with preset terms
// if there are 20M deposited then the deallocation function kicks in across all positions for the vesting schedule created during the launch phase

// in main phase if you LP then your vesting schedule is locked at whatever rate it is and put into a gamma strategy

// how to handle migration with boosting, etc...
// managing protocol fees and swapping and distributing them
/**
     createVLP() Arguments:
        - Uniswap AMM contract to deposit into
        - LP % share ownership on each side
        - vesting schedule
        - access rules struct (same as Aelin - private, NFT gated or merkle)
        - launch phase struct
            - pairing (dont need for the main arguments if there is already liquidity right?)
            - boolean (has launch phase?) 
            - initial price
            - deposit window
            - deposit window allocation strategy
            - window to LP funds to AMM or else investors can withdraw
        - array of single sided rewards struct (cap 10)
            - token to send
            - vesting schedule
            - reward per quote asset deposited
     */

// step 1 - creates a VLP with the arguments listed above
// step 2 - funds the deal with finalizeVLP

// is liquidity launch Phase?
// step 3 - acceptDeal called for investors to send quote assets (maybe this should be a different method)
// step 4 - the deposit window ends and then the protocol has a window to call a method to LP the phase 0 tokens
// step 5 - the investors in the deal need to call settle if there was deallocation allowed to get their LP assets but they will start vesting at the right time before settled is called

// is main Phase?
// step 3 - acceptDeal called for investors to send quote assets
// step 4 - pause and change rewards callable by the protocol at any time
// step 5 - when the rewards run out then what happens??? they can always add more but maybe we should have a weekly LP lock function for users with no rewards who want to get protocol fees

// check if there is a way to handle upgrading LP tokens to uni v4 for example

// Fee Module methods
// 1. claimFees() callable for each locked LP whose amounts are tracked as a % of total stakers each week
