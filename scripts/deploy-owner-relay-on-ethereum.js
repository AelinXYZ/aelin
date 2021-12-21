const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const OwnerRelayOnEthereum = await ethers.getContractFactory(
    "OwnerRelayOnEthereum"
  );
  // the L1 gnosis safe
  const owner = "0x51b0332E1b3349bcF01689E63e34d8859595e376";
  // the optimism messenger (Proxy__OVM_L1CrossDomainMessenger)
  // from https://github.com/ethereum-optimism/optimism/blob/ef5343d61708f2d15f51dca981f03ee4ac447c21/packages/contracts/deployments/README.md
  const messengerAddress = "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1";
  // NOTE you need to deploy OwnerRelayOnOptimism first so you have this address
  const relayOnOptimism = "0x88FdC711EFF5877B464D299C7ac3077135C6C5ca";
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
