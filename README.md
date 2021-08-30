# Aelin

Aelin is a fundraising protocol built on Ethereum

TODO add license and update README with more info about how the protocol works

### Running Integration Tests

The integration tests require that hardhat run a fork of mainnet (see [docs](https://hardhat.org/hardhat-network/guides/mainnet-forking.html)). For this to work you must do the following:

1. setup an [Alchemy](https://www.alchemy.com/) account (it is free)
2. create an app and get the `https` key
3. `export ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/<key>`

NOTE: the first time you run the test it will be slow. Hardhat caches the requests to Alchemy, so it will be faster on subsequent runs

### Deploying to Kovan

1. export ALCHEMY_API_KEY (just the key part) from step 2 in running integration tests.
2. grab an Ethereum private key and get some Kovan ETH on it. `export KOVAN_PRIVATE_KEY=<key>`.
3. `npm run compile` (necessary?)
4. `npm run deploy-deal:kovan`
5. take the address of the deployed deal from the CLI and paste it in AelinPool.sol under `AELIN_DEAL_ADDRESS`
6. `npm run compile` (necessary?)
7. `npm run deploy-pool:kovan`
8. take the address of the deployed pool from the CLI and paste it in AelinPool.sol under `AELIN_POOL_ADDRESS`
9. `npm run compile` (necessary?)
10. `npm run deploy-pool-factory:kovan`
