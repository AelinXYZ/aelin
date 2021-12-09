const { ethers } = require("hardhat");

// NOTE that we want to hardcode the Deal and Pool logic addresses
// in the AelinPoolFactory before deployment
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct fields for each deployment
  const poolLogicAddress = "";
  const dealLogicAddress = "";
  const rewardsAddress = "";

  // latest Kovan addresses
  // "0xbA615F3aa6384F642DBFB729E1d157524f0334b3",
  // "0xa2cc163735DF76fB3fa4BD0F971a02b5F217C93C",
  // "0x2C1dA0F3A1E2916cA9B8F33C6E12d75eC2f975aa"

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
