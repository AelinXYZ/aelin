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

    /**
     Arguments:
        - indicate if this is the launch phase and if so, we need 
            - initial price
            - deposit window
            - deposit window allocation strategy
            - maybe need a window to submit funds to AMM or else investors get their funds back
        - pair data
        - LP % share on each side
        - vesting schedules
        - access rules (private, NFT gated or merkle)
        - migration boolean or rules struct (if true you can just deposit your old LP tokens and lock them on a vesting schedule which will auto calculate your sUSD share and then give you double or maybe the same amount of single sided rewards)
        - array of single sided rewards and rules
            - token to send
            - vesting schedule
            - reward per quote asset deposited 
     */
    function createVLP() external returns (address vlpAddress) {
        vlpAddress = _cloneAsMinimalProxy(AELIN_VLP_LOGIC, "Could not create new deal");

        AelinVLP(vlpAddress).initialize();

        emit CreateVLP(true);
    }
}

// in the AelinVLP contract we need
// 1. finalizeVLP()
//      - deposit tokens to finalize the deal. you can send in all the different tokens all at once or different times
// 2. acceptDeal() for investors to send in quote assets
//      - takes out fees from LP side and single sided rewards and sends to official AELIN Fee Module
//      - pairs against protocol tokens and deposits into AMM
//      - sets LP tokens into vesting scheule for the investor
//      - gives single sided rewards to user (with vesting schedule attached or not)
//      - tracks % ownership of total LP assets for the Fee Module to track for claiming fees
// 3. migrate() for investors to send in LP tokens
// 4. settle() for investors at the end of phase 0 but only if they can deallocate maybe?
// 5. pause() from the protocol side stops new entrants from participating and allows them to make changes. minimum of 15 mins when you pause something maybe to unpause.
// 6. removeRewards() to take back the reward tokens. Need to distinguish here between some or all of the rewards
// 7. vestingLP() to claim their LP tokens
// 8. vestingSingle() to claim their single sided tokens on vesting schedules
// 9. createInitialLiquidity() to create the pool and deposit assets after phase 0 ends
// 10. acceptDealInitial() for when there is no liquidity and they have a phase 0 (might be able to merge with regular accept deal)
// 11. settle() to be called at the end of phase 0 by each investor (or maybe only one investor needs to call it. tbd)
// 12. weeklyLock() to allow anyone to deposit LP tokens locked for 1 week at a time to get access to the Fee Module with no boost

// NFT gated pools
// merkle deal pools
// private pools

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

// NOTE should we put a window on rewards in the main phase for whatever reason? no, they can pause and take them back.
// check if there is a way to handle upgrading LP tokens to uni v4 for example

// Fee Module methods
// 1. claimFees() callable for each locked LP whose amounts are tracked as a % of total stakers each week
