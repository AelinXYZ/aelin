import { HardhatUserConfig } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-interact";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "dotenv/config";
import "hardhat-cannon";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
    ],
  },
  defaultNetwork: "cannon",
  mocha: {
    // this needs to be long because CI takes a while to fork mainnet data from alchemy
    timeout: 1000000,
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_ARB_API_KEY}`,
  },
  networks: {
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${process.env.OP_API_KEY}`,
      accounts: [`0x${process.env.OP_PRIVATE_KEY}`],
      chainId: 10,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.MAINNET_PRIVATE_KEY}`],
      gasMultiplier: 1.5,
      chainId: 1,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.KOVAN_PRIVATE_KEY}`],
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.GOERLI_PRIVATE_KEY}`],
      chainId: 5,
    },
    arbitrum: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.ARBITRUM_PRIVATE_KEY}`],
      chainId: 42161,
    },
    "arbitrum-goerli": {
      url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.GOERLI_PRIVATE_KEY}`],
      chainId: 421613,
    },
    hardhat: {
      initialBaseFeePerGas: 0,
      forking: {
        url: process.env.ALCHEMY_URL || "",
        blockNumber: 13123510,
        enabled: !!process.env.ALCHEMY_URL,
      },
    },
  },
};

export default config;
