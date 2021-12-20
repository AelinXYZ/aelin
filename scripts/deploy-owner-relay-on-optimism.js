const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const OwnerRelayOnOptimism = await ethers.getContractFactory(
    "OwnerRelayOnOptimism"
  );
  // TODO use the same private key in set-bridge-contract-data and call-direct-relay after this is deployed
  const privateKey = "";
  const signer = new ethers.Wallet(privateKey);
  // NOTE deploy, test directRelay from the owner to make sure it is working
  // also call setContractData from the owner before the ownershipDuration is done
  const temporaryOwner = signer.address;
  // one hour of ownership on the contract to test direct relay and set the contract data
  const ownershipDuration = 5 * 60 * 60; // 5 hours to start for testing
  const ownerRelayOnOptimism = await OwnerRelayOnOptimism.deploy(
    temporaryOwner,
    ownershipDuration
  );

  console.log("OwnerRelayOnOptimism address:", ownerRelayOnOptimism.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
