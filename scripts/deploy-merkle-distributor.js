const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const MerkleDistributor = await ethers.getContractFactory(
    "MerkleDistributor"
  );

  const owner = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";
  const token = "0x780f70882fF4929D1A658a4E8EC8D4316b24748A";
  const merkleRoot =
    "0x3029819ce3dda49ac1f785ea37adc4ad84949bc7cfd3123711b57d7f9fd2c71c";
  const merkleDistributor = await MerkleDistributor.deploy(
    owner,
    token,
    merkleRoot
  );
  console.log("MerkleDistributor address:", merkleDistributor.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
