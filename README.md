# aelin

Aelin is a fundraising protocol built on Ethereum

TODO add license and update README with more info about how the protocol works

### Running Integration Tests

The integration tests require that hardhat run a fork of mainnet (see [docs](https://hardhat.org/hardhat-network/guides/mainnet-forking.html)). For this to work you must do the following:
1. setup an [Alchemy](https://www.alchemy.com/) account (it is free)
2. create an app and get the `https` key
3. export ALCHEMY_URL=https://eth-mainnet.alchemyapi.io/v2/<key>

NOTE: the first time you run the test it will be slow. Hardhat caches the requests to Alchemy, so it will be faster on subsequent runs