const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const MerkleDistributor = await ethers.getContractFactory(
    "MerkleDistributor"
  );

  const owner = deployer.address;
  const token = "0xf1f2fb3c8E90152e75D7675F5A7F3f9f95e65A81";
  const merkleRoot =
    "0x1108141c9e59900f8888254dc09978c13944f1d69f47b1c0c4f2ed769c66410e";
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
