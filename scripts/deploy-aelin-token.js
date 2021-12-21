const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct dao address for each deployment
  const optimismTreasury = "0x55c1688587e6DfD52E44BF8B7028a8f7525296E7";

  const AelinToken = await ethers.getContractFactory("AelinToken");
  const aelinToken = await AelinToken.deploy(optimismTreasury);

  console.log("AelinToken address:", aelinToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
