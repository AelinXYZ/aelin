# Aelin

Aelin is a fundraising protocol built on Ethereum

TODO add license and update README with more info about how the protocol works

### Development workflow and Integration Test Setup

DUE TO THE USAGE OF CREATE2 (https://docs.openzeppelin.com/cli/2.8/deploying-with-create2)
Every time there is a contract change and you want the integration tests to work you need to do the following

1. `npm run deploy-deal:mainnet-fork`
2. take the address of the deployed deal from the CLI and paste it in AelinPool.sol under `AELIN_DEAL_ADDRESS`
3. `npm run deploy-pool:mainnet-fork`
4. take the address of the deployed pool from the CLI and paste it in AelinPool.sol under `AELIN_POOL_ADDRESS`
5. `npm run compile`
6. `npm test` should work now

The integration tests require that hardhat run a fork of mainnet (see [docs](https://hardhat.org/hardhat-network/guides/mainnet-forking.html)). For this to work you must do the following:

1. setup an [Alchemy](https://www.alchemy.com/) account (it is free)
2. create an app and get the `https` key
3. `export ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/<key>`

NOTE: the first time you run the test it will be slow. Hardhat caches the requests to Alchemy, so it will be faster on subsequent runs

### Deploying - mainnet only needs to be deployed once

1. export ALCHEMY_API_KEY (just the key part) from step 2 in running integration tests.
2. grab an Ethereum private key and get some Kovan ETH on it. `export KOVAN_PRIVATE_KEY=<key>`.
3. `npm run deploy-deal:<network>`
4. take the address of the deployed deal from the CLI and paste it in AelinPool.sol under `AELIN_DEAL_ADDRESS`
5. `npm run deploy-pool:<network>`
6. take the address of the deployed pool from the CLI and paste it in AelinPool.sol under `AELIN_POOL_ADDRESS`
7. `npm run deploy-pool-factory:<network>`
