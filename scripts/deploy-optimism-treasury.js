const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // NOTE the L2 bridge contract which is owned by the L1 multisig will own the treasury
  // The L1 multisig will call change ownership to a L2 multisig once gnosis is live on Optimism
  const owner = "";

  const OptimismTreasury = await ethers.getContractFactory("OptimismTreasury");
  const optimismTreasury = await OptimismTreasury.deploy(owner);

  console.log("OptimismTreasury address:", optimismTreasury.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
