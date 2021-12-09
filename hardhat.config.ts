import { HardhatUserConfig } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-web3";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: {
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
  defaultNetwork: "hardhat",
  mocha: {
    // this needs to be long because CI takes a while to fork the mainnet data from alchemy
    timeout: 1000000,
  },
  networks: {
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
