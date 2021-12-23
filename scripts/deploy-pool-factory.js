const { ethers } = require("hardhat");

// NOTE that we want to hardcode the Deal and Pool logic addresses
// in the AelinPoolFactory before deployment
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct fields for each deployment - these are mainnet values
  // const poolLogicAddress = "0x88FdC711EFF5877B464D299C7ac3077135C6C5ca";
  // const dealLogicAddress = "0x2569f66b7Acd8954A7B3A48481823e30c4990742";
  // const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

  // mainnet OP deployed contracts
  const poolLogicAddress = "0xE30bD5fb0A652a65eB378AB952A621f0b509521d";
  const dealLogicAddress = "0xBca527108Bcc3DE437C5Bfdb1A5489DE26DeEaE0";
  const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

  const AelinPoolFactory = await ethers.getContractFactory("AelinPoolFactory");
  const aelinPoolFactory = await AelinPoolFactory.deploy(
    poolLogicAddress,
    dealLogicAddress,
    rewardsAddress
  );

  console.log("AelinPoolFactory address:", aelinPoolFactory.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
