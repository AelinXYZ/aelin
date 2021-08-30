const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const AelinDeal = await ethers.getContractFactory("AelinDeal");
  const aelinDeal = await AelinDeal.deploy();

  console.log("AelinDeal address:", aelinDeal.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
