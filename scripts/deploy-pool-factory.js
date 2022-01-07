const { ethers } = require("hardhat");

// NOTE that we want to hardcode the Deal and Pool logic addresses
// in the AelinPoolFactory before deployment
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // TODO fill out the correct fields for each deployment - these are mainnet values
  // const poolLogicAddress = "0x80aFb16eB991BC0a5Bfc0515A562dAD362084C4b";
  // const dealLogicAddress = "0x2569f66b7Acd8954A7B3A48481823e30c4990742";
  // const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

  // mainnet v2
  // const poolLogicAddress = "0x4465A2a34684D5fDe76EfD1597553F6D81617412";
  // const dealLogicAddress = "0x1fa677ca369b97Ab30707373531cB050b1c3a7c6";
  // const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

  // mainnet OP deployed contracts
  // const poolLogicAddress = "0x689b7D709106bc488f872C50B688F058048536BE";
  // const dealLogicAddress = "0xBca527108Bcc3DE437C5Bfdb1A5489DE26DeEaE0";
  // const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

  // mainnet OP deployed contracts v2
  // const poolLogicAddress = "0x528D21fd31b0764BefBF5b584f962e3cE7Dda296";
  // const dealLogicAddress = "0x3c8BEf5F8Df313ea6cb874d5035d3eeb963d8dAd";
  // const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

  // kovan deployed contracts
  const poolLogicAddress = "0x41AC86ba18eE264aFe78E8d39547abE547b2b25b";
  const dealLogicAddress = "0xe3a1c4fF151c53D0b65F42B601715F472078C336";
  const rewardsAddress = "0x7856f2a12A7A18b4A115d295F548434a9b078fA1";

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
