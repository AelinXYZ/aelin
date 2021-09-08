# Aelin Overview

Aelin is a fundraising protocol built on Ethereum. A sponsor goes out and announces they are raising a pool of capital with a purchase expiry period. Anyone with an internet connection, aka the purchaser, can contribute funds (e.g. sUSD) to the pool; the funds are locked for a time duration period while the sponsor searches for a deal.

If a deal is found, the sponsor agrees to a deal with a holder and announces the deal to the purchasers. At this point in time the purchaers can convert their pool shares to deal shares, which represent a claim on the underlying deal token. The deal share might include a vesting schedule or not, depending upon the deal. If a deal is not found then the purchasers can take their money back at the end of the pool duration.

If the purchaers are not interested in the underlying deal token they are welcome to withdraw their capital at this point in time. Note that since the underlying deal tokens vesting are wrapped as an ERC20 they may be sold or traded before the vesting period is over.

### Key terms

`Sponsor` - the entity or individual raising capital to pursue a deal
`Holder` - the entity or individual seeking capital in exchange for an underlying deal token
`Purchaser` - the entity or individual providing capital in exchange for a possible investment opportunity

`Purchase token` - the token sent to the pool by the Purchaser
`Pool token` - the wrapped token received by the Purchaser as an indicator of their contribution to the pool. Represents a claim on the purchase token if the purchaser is not interested in the deal.
`Deal token` - the wrapped token received by the Purchaser as an indicator of their acceptance of the deal. Optionally wraps the underlying deal token in a vesting schedule.
`Underlying deal token` - the final token given to the purchaser in exchange for their purchase tokens at the end of the vesting period if they accepted the deal.

`Aelin Fee` - 2% fee to the protocol taken from every purchaser when they accept a deal.
`Sponsor Fee` - optional fee set by the sponsor when they announce the pool. can range from 0 to 98%.

### User journeys

### Development workflow and Integration Test Setup

The integration tests require that hardhat run a fork of mainnet (see [docs](https://hardhat.org/hardhat-network/guides/mainnet-forking.html)). For this to work you must do the following:

1. setup an [Alchemy](https://www.alchemy.com/) account (it is free)
2. create an app and get the `https` key
3. `export ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/<key>`

NOTE: the first time you run the test it will be slow. Hardhat caches the requests to Alchemy, so it will be faster on subsequent runs

#### Deploying

1. export ALCHEMY_API_KEY (just the key part) from step 2 in running integration tests.
2. grab an Ethereum private key and get some Kovan ETH on it. `export KOVAN_PRIVATE_KEY=<key>`.
3. `npm run deploy-deal:<network>` - take the address of the deployed deal from the CLI and save it for later usage
4. `npm run deploy-pool:<network>` - take the address of the deployed pool from the CLI and save it for later usage
5. `npm run deploy-pool-factory:<network>`

NOTE after the deployment is done, when creating a UI to call the AelinPoolFactory.createPool method you will need to pass in the addresses from step 3 and 4 as `_aelinDealLogicAddress` and `_aelinPoolLogicAddress`

#### Sponsor

1. Create a pool by calling `AelinPoolFactory.createPool()`

Arguments:

- `string memory _name` - used as part of the name of the ERC20 pool and deal token
- `string memory _symbol` - used as part of the symbol of the ERC20 pool and deal token
- `uint _purchaseTokenCap`- the max amount of purchase tokens that can be used to buy pool tokens. if set to 0 the deal is uncapped
- `address _purchaseToken` - the purchase token used to buy the pool token
- `uint _duration` - the duration of the pool. if no deal is created by the end of the duration, the purchaser may withdraw their funds
- `uint _sponsorFee`- an optional fee from the sponsor set between 0 and 98%
- `address _sponsor` - the address of the sponsor
- `uint _purchaseExpiry` - the amount of time a purchaser has to buy a pool token
- `address _aelinDealLogicAddress` - once the AelinDeal.sol contract has been deployed you need to pass in that address here. will be done from the UI automatically without the sponsor needing to find it

Requirements:

- the `_duration` must be less than 1 year (revert)
- the `_purchaseExpiry` must be greater than 30 mins (revert)
- the `_sponsorFee` must be less than 98% (revert)

2. ...
