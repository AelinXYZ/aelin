const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const OwnerRelayOnEthereum = await ethers.getContractFactory(
    "OwnerRelayOnEthereum"
  );
  const owner = "";
  const messengerAddress = "";
  // NOTE you need to deploy OwnerRelayOnOptimism first so you have this address
  const relayOnOptimism = "";
  const ownerRelayOnEthereum = await OwnerRelayOnEthereum.deploy(
    owner,
    messengerAddress,
    relayOnOptimism
  );

  console.log("OwnerRelayOnEthereum address:", ownerRelayOnEthereum.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
