const { ethers } = require("hardhat");

// NOTE a mainnet version of this contract is already deployed here: 0x4a27c059FD7E383854Ea7DE6Be9c390a795f6eE3
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Create2Factory = await ethers.getContractFactory("Create2Factory");
  const create2Factory = await Create2Factory.deploy();

  console.log("Create2Factory address:", create2Factory.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
