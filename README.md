# Aelin Overview

Aelin is a fundraising protocol built on Ethereum. A sponsor goes out and announces they are raising a pool of capital with a purchase expiry period. The sponsor can create a public or private pool. If it is a public pool, qnyone with an internet connection, aka the purchaser, can contribute funds (e.g. sUSD) to the pool during the purchase expiry period; after the purchase expiry period, the funds are locked for a time duration period while the sponsor searches for a deal. Private pools are reserved for an allow list of addresses with specified investment amounts.

If the sponsor finds a deal with the holder of a tokenized asset after the purchase expiry period, the sponsor announces the deal terms to the purchasers and then the holder has a specified time period to send the underlying deal tokens/ tokenized assets to the contract. If the funds are sent, the purchasers can convert their pool tokens (or a partial amount) to deal tokens, which represent a claim on the underlying deal token. Pool tokens are transferable until the deal is created and fully funded. After the deal is funded, pool tokens must be either accepted or withdrawn for the purchase token. If the holder does not send the underlying deal tokens in time, the sponsor can create a new deal for the pool.

If the purchasers are not interested in the underlying deal token they are welcome to reject the deal and withdraw their capital after the deal terms are announced. Also if a deal is not found then the purchasers can take their money back at the end of the pool duration.

The deal token is an ERC20 that might include a vesting schedule or not to claim the underlying deal token, depending upon the deal. Since the unvested underlying deal tokens are wrapped as an ERC20 they may be sold or traded before the vesting period is over. However, all vested tokens will be claimed and the respective deal tokens burned before any transfer occurs.

## Key terms

- `Sponsor` - the entity or individual raising capital to pursue a deal

- `Holder` - the entity or individual seeking capital in exchange for an underlying deal token they hold

- `Purchaser` - the entity or individual providing capital in exchange for a possible investment opportunity

- `Purchase token` - the token that the sponsor requires the Purchaser use to buy into the pool

- `Pool token` - the wrapped token received by the Purchaser as an indicator of their contribution to the pool. Represents a claim on the purchase token if the purchaser is not interested in the deal.

- `Deal token` - the wrapped token received by the Purchaser as an indicator of their acceptance of the deal. Optionally wraps the underlying deal token in a vesting schedule.

- `Underlying deal token` - the final token given to the purchaser in exchange for their purchase tokens at the end of the vesting period if they accepted the deal.

- `Aelin Fee` - 2% fee to the protocol taken from every purchaser when they accept a deal.

- `Sponsor Fee` - optional fee set by the sponsor when they announce the pool. can range from 0 to 98%.

## User journeys

### **SPONSOR**

**SPONSOR STEP 1 (Create a Pool)**: Create a pool by calling `AelinPoolFactory.createPool(...)`

Arguments:

- `string memory _name` used as part of the name of the ERC20 pool and deal token
- `string memory _symbol` used as part of the symbol of the ERC20 pool and deal token
- `uint _purchaseTokenCap`- the max amount of purchase tokens that can be used to buy pool tokens. if set to 0 the deal is uncapped
- `address _purchaseToken` the purchase token used to buy the pool token
- `uint _duration` the duration of the pool which starts after the purchase expiry period ends. if no deal is created by the end of the duration, the purchaser may withdraw their funds
- `uint _sponsorFee`- an optional fee from the sponsor set between 0 and 98%
- `uint _purchaseDuration` the amount of time a purchaser has to buy a pool token before the sponsor can create the deal

Requirements:

- the `_duration` must be <= 1 year (revert)
- the `_purchaseDuration` must be >= 30 minutes and <= 30 days (revert)
- the `_sponsorFee` must be between 0% and 98% (revert)

NOTE if SPONSOR never finds a deal this is the end of their journey and the PURCHASER can retrieve their purchase tokens at the end of the `_duration`

If a deal is found, the SPONSOR must wait for `PURCHASER step 1 (Enter the Pool)` to be completed and the purchase expiry period to end before going to create a deal in step 2.

**SPONSOR STEP 2 (Create a Deal)**: Creates a deal by calling `AelinPool.createDeal(...)`

Modifiers:

- `onlySponsor` and `dealNotCreated` only the sponsor may call this method before a deal is created

Arguments:

- `address _underlyingDealToken` the underlying deal token a purchaser receives upon vesting
- `uint _purchaseTokenTotalForDeal` the total amount of purchase tokens that can be converted for the deal tokens
- `uint _underlyingDealTokenTotal` the total amount of underlying deal tokens all purchasers receive upon vesting
- `uint _vestingPeriod` the total amount of time to fully vest starting at the end of the vesting cliff (vesting is linear for v1)
- `uint _vestingCliff` the initial deal token holding period where no vesting occurs
- `address _holder` the entity or individual with whom the sponsor agrees to a deal
- `uint _holderFundingDuration` the amount of time a holder has to fund the deal before the proposed deal expires

> NOTE please be sure to understand how the 2 redemption periods work outlined below:

- `uint _proRataRedemptionPeriod` the time a purchaser has to redeem their pro rata share of the deal. E.g. if the `_purchaseTokenTotalForDeal` is only 8M sUSD but the pool has 10M sUSD (4:5) in it then for every $1 the purchaser invested they get to redeem $0.80 for deal tokens during this period. If the proRataConversion rate is 1:1 there is no open redemption period
- `uint _openRedemptionPeriod` is a period after the `_proRataRedemptionPeriod` when anyone who maxed out their redemption in the `_proRataRedemptionPeriod` can use their remaining purchase tokens to buy any leftover deal tokens if some other purchasers did not redeem some or all of their pool tokens for deal tokens

Requirements:

- the `block.timestamp >= purchaseExpiry` (revert)
- the `_holderFundingDuration` must be >= 30 minutes and <= 30 days (revert)
- the `_proRataRedemptionPeriod` must be >= 30 minutes and <= 30 days (revert)
- the `_openRataRedemptionPeriod` must be >= 30 minutes and <= 30 days, If the proRataConversion rate is not 1:1, otherwise it must be 0 (revert)
- the `_purchaseTokenTotalForDeal` converted to 18 decimals must be <= totalSupply of pool tokens (revert)

NOTE the sponsor journey has ended IF the holder funds the deal. From here the next step is `HOLDER step 1 (Fund the Deal)`. However, if the holder does not fund the deal a sponsor can create a new deal for the pool by calling `AelinPool.createDeal(...)` again. There is always only 1 deal per pool.

**`EXTRA_METHODS`**: only the sponsor may also call `setSponsor()` followed by `acceptSponsor()` from the new address at any time to update the sponsor address for a deal

### **PURCHASER**

**PURCHASER STEP 1 (Enter the Pool)**: Purchase pool tokens by calling `AelinPool.purchasePoolTokens(...)`.

Arguments:

- `uint _purchaseTokenAmount` - the amount of the purchase token to use to buy pool tokens

Requirements:

- the `_purchaseTokenAmount` when converted to 18 decimal format plus the `totalSupply` of the pool token must be <= `poolTokenCap` unless the cap is set to 0 (revert)
- the pool tokens must be purchased when `block.timestamp` <= `purchaseExpiry`

NOTE after `PURCHASER step 1 (Enter the Deal)` is `SPONSOR step 2 (Create the Deal)` and then `HOLDER step 1 (Fund the Deal)` followed by `PURCHASER step 2 (Accept or Reject the Deal)`. NOTE if a sponsor never creates a deal the purchaser can withdraw their funds the same way as if they reject the deal

**PURCHASER STEP 2 (Accept or Reject the Deal)**: At step two the purchaser has 2 options: reject or accept the deal. At this point they can no longer transfer their pool tokens.<space><space>

**OPTION 1 - REJECT**: Rejects a portion of or all of the deal offered by calling `AelinPool.withdrawMaxFromPool()` or `withdrawFromPool(uint purchaseTokenAmount)`

Arguments:

- `uint purchaseTokenAmount` used when withdrawing a specific amount and not all your tokens by calling the max function instead

Requirements:

- `block.timestamp > poolExpiry` the method can only be called after the pool has expired which can happen at the end of the `_duration` or when the deal is created (revert)<space><space>

**OPTION 2 - Accept**: NOTE the deal acceptance phase can have several steps under various circumstances outlined below<space><space>

**Accept when Conversion Ratio == 1:1** (e.g. a pool has $10M sUSD in it and the deal is for $10M sUSD)

- **PRO RATA PERIOD**: The purchaser can either call `AelinPool.acceptDealTokens(uint poolTokenAmount)` or `AelinPool.acceptMaxDealTokens()` while the `block.timestamp < proRataRedmeptionExpiry`. In this case calling max will send all of their purchase tokens to the `HOLDER`, send 2% of the deal tokens to the `AELIN_REWARDS` address for `Aelin` token stakers, and an optional % from 0 to 98 to the `SPONSOR` which was set as the `sponsorFee` in the pool creation at the beginning of the process. If not accepting max, any additional tokens may be withdrawn at any time

- **OPEN REDEMPTION PERIOD**:
  (n/a - since the ratio is 1:1 all purchasers have already had the chance to max their contributions)

**Accept when Conversion Ratio is less than 1:1** (e.g. a pool has $10M sUSD in it but the deal is for $8M sUSD)

- **PRO RATA PERIOD**:

  - **DOES NOT MAX Accept**. the purchaser only accepts a portion of their tokens by calling `AelinPool.acceptDealTokens(uint poolTokenAmount)` while the `block.timestamp < proRataRedmeptionExpiry`. They may withdraw their remaining amount at any time. E.g. a user who purchased $100 sUSD of pool tokens only accepts $50 instead of their full $80 allocation

  - **DOES MAX Accept**: the purchaser accepts all of their deal tokens by calling `AelinPool.acceptMaxDealTokens()` while the `block.timestamp < proRataRedmeptionExpiry`. E.g. a user who purchased $100 sUSD of pool tokens accepts $80

- **OPEN REDEMPTION PERIOD**:

  - **DID NOT MAX ACCEPT**: if the purchaser did not max out their allocation in the `proRataRedemptionPeriod` they are not eligible to participate in the open redemption period (revert)

  - **DID MAX ACCEPT**: if the purchaser maxed their allocation they may redeem their remaining purchase tokens for deal tokens up until they have used all their funds or the deal cap has been reached. They can do this by calling `AelinPool.acceptMaxDealTokens()` or `AelinPool.acceptDealTokens(uint poolTokenAmount)` while the `block.timestamp < openRataRedmeptionExpiry`

### **HOLDER**

**HOLDER STEP 1 (Fund the Deal)**: After the deal has been created by the sponsor, the holder (or any address on behalf of the holder) funds the deal by calling `AelinDeal.depositUnderlying(...)`

Modifiers:

- `finalizeDepositOnce` once the full deal amount is deposited this method can no longer be called

Arguments:

- `uint _underlyingDealTokenAmount` the amount of the underlying deal token to deposit when calling this method. NOTE if the holder accidentally transfers the funds without using this method they can still call it with `_underlyingDealTokenAmount` set to 0 to finalize the deal creation

The holder is nearly done. The only remaining step for them is to withdraw any excess funds accidentally deposited now or at the end of the expiry period if not all the deal tokens have been redeemed by purchasers.

After calling `AelinDeal.depositUnderlying(...)`, the deal `proRataDealRedemption` period starts and `Purchaser step 2` begins

**`EXTRA_METHODS`**: only the holder may also call `setHolder()` followed by `acceptHolder()` from the new address at any time to update the holder address for a deal

## Development workflow and Integration Test Setup

The integration tests require that hardhat run a fork of mainnet (see [docs](https://hardhat.org/hardhat-network/guides/mainnet-forking.html)). For this to work you must do the following:

1. setup an [Alchemy](https://www.alchemy.com/) account (it is free)
2. create an app and get the `https` key
3. `export ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/<key>`

NOTE: the first time you run the test it will be slow. Hardhat caches the requests to Alchemy, so it will be faster on subsequent runs

Environment variables needed for the codebase in addition to `ALCHEMY_URL`

1. `export KOVAN_PRIVATE_KEY=...` any private key with some kovan ETH on it for deployment
2. `export ALCHEMY_API_KEY=...` the same key at the end of the `ALCHEMY_URL` environment variable but it needs to be in its own environment variable.

#### Deploying

1. export ALCHEMY_API_KEY (just the key part) from step 2 in running integration tests.
2. grab an Ethereum private key and get some Kovan ETH on it. `export KOVAN_PRIVATE_KEY=<key>`.
3. `npm run deploy-deal:<network>` - take the address of the deployed deal from the CLI and paste it in the `AelinPoolFactory` as `address constant AELIN_DEAL_LOGIC = ...`
4. `npm run deploy-pool:<network>` - take the address of the deployed pool from the CLI and paste it in the `AelinPoolFactory` as `address constant AELIN_POOL_LOGIC = ...`
5. `npm run deploy-pool-factory:<network>`
