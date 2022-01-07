import { HardhatUserConfig } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-web3";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-interact";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";

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
  defaultNetwork: "hardhat",
  mocha: {
    // this needs to be long because CI takes a while to fork the mainnet data from alchemy
    timeout: 1000000,
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_API_KEY}`,
  },
  networks: {
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${process.env.OP_API_KEY}`,
      accounts: [`0x${process.env.OP_PRIVATE_KEY}`],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.OP_PRIVATE_KEY}`],
      gasMultiplier: 1.5,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.KOVAN_PRIVATE_KEY}`],
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
