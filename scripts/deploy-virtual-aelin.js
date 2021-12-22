const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct dao address for each deployment
  const preDistributionAddress = "0x7856f2a12A7A18b4A115d295F548434a9b078fA1";

  const VirtualAelinToken = await ethers.getContractFactory(
    "VirtualAelinToken"
  );
  const virtualAelinToken = await VirtualAelinToken.deploy(
    preDistributionAddress
  );

  console.log("VirtualAelinToken address:", virtualAelinToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
