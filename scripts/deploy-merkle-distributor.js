const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const MerkleDistributor = await ethers.getContractFactory(
    "MerkleDistributor"
  );

  const owner = deployer.address;
  const token = "0x07aa6CfD846Ff4e39178f414Dc27eC890d9622a2";
  const merkleRoot =
    "0xa19a483a030526c1a462ae6c5cd56d722f35e7ee2bb0846925f2363e96f547a5";
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
