const { ethers } = require("hardhat");

// NOTE that we want to hardcode the Deal and Pool logic addresses
// in the AelinPoolFactory before deployment
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct fields for each deployment
  // optimism deployed contracts
  const owner = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";
  const vAelinAddress = "0x780f70882fF4929D1A658a4E8EC8D4316b24748A";
  const aelinAddress = "0x61BAADcF22d2565B0F471b291C475db5555e0b76";

  // kovan deployed contracts
  // const owner = "0x7856f2a12A7A18b4A115d295F548434a9b078fA1";
  // const vAelinAddress = "0xb7ABB959Def630d1402F202b8BC31BbaCBcDafBA";
  // const aelinAddress = "0x50263AFE9Ea8Ded3DaD1a9Af96Fc366bB5d96bfa";

  const VAelinConverter = await ethers.getContractFactory("VAelinConverter");
  const vAelinConverter = await VAelinConverter.deploy(
    owner,
    vAelinAddress,
    aelinAddress
  );

  console.log("VAelinConverter address:", vAelinConverter.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
