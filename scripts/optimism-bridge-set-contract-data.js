const { ethers } = require("hardhat");
const OwnerRelayOnOptimismArtifact = require("../artifacts/contracts/OwnerRelayOnOptimism.sol/OwnerRelayOnOptimism.json");

async function main() {
  const bridgeAddress = "0x88FdC711EFF5877B464D299C7ac3077135C6C5ca";

  const [deployer] = await ethers.getSigners();
  const ownerRelayOnOptimism = await ethers.getContractAt(
    OwnerRelayOnOptimismArtifact.abi,
    bridgeAddress
  );
  // use OVM_L2CrossDomainMessenger
  // from https://github.com/ethereum-optimism/optimism/blob/ef5343d61708f2d15f51dca981f03ee4ac447c21/packages/contracts/deployments/README.md
  const messengerAddress = "0x4200000000000000000000000000000000000007";
  // TODO step 1 deploy optimism relay, step 2 deploy ethereum relay, step 3 paste the address, step 4 run this script
  const relayOnEthereum = "0x02b9E99a05458d763256B977E61c1d947a5a0d04";

  const tx = await ownerRelayOnOptimism
    .connect(deployer)
    .setContractData(messengerAddress, relayOnEthereum);
  console.log("tx submitted", tx);
  // tx hash to set data on OP 0xa0cca34b7b07d2576e12e2eaa1158462f8f8c00d4f3c181e53daab884a8e8e6b
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
