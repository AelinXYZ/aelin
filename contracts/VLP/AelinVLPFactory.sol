// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../MinimalProxyFactory.sol";
import "./AelinVLP.sol";
import "../libraries/AelinNftGating.sol";
import "../libraries/AelinAllowList.sol";
import {IAelinVLP} from "../interfaces/IAelinVLP.sol";

contract AelinUpFrontDealFactory is MinimalProxyFactory, IAelinUpFrontDeal {
    using SafeERC20 for IERC20;

    address public immutable AELIN_VLP_LOGIC;

    constructor() {
        AELIN_VLP_LOGIC = new AelinVLP();
    }

    // problems
    // how to combine both phases together logistically
    // you have the first phase and then what happens
    // in the first phase you LP all at once - how to split up the vesting contracts for this purpose
    // you have a mega LP vesting contract that can be split between smaller contracts
    // how to handle migration
    /**
     createVLP() Arguments:
        - launch phase struct
            - boolean (has launch phase?) 
            - initial price
            - deposit window
            - deposit window allocation strategy
            - window to LP funds to AMM or else investors can withdraw
        - AMM data struct (could be an array maybe using multiple AMMs)
            - AMM contract to deposit into
            - pairing
            - weighting
            - LP % share ownership on each side
            - vesting schedules
            - access rules (private, NFT gated or merkle)
        - array of single sided rewards struct (cap 10)
            - token to send
            - vesting schedule
            - reward per quote asset deposited
            - migration struct
                - boolean (if can migrate)
                - reward per quote asset deposited (different value available for migrating)
                - vesting schedule
     */
    function createVLP() external returns (address vlpAddress) {
        vlpAddress = _cloneAsMinimalProxy(AELIN_VLP_LOGIC, "Could not create new deal");

        AelinVLP(vlpAddress).initialize();

        emit CreateVLP(true);
    }
}

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
