const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  if (process.env.DEVELOPMENT) {
    console.log("local network dev mode");
    // in development hardhat sets the block gas limit too low at only 3M
    await ethers.provider.send("evm_setBlockGasLimit", [
      `0x${ethers.BigNumber.from(6000000)}`,
    ]);
    await ethers.provider.send("evm_mine", []);
  }

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
