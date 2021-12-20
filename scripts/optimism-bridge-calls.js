const { ethers } = require("hardhat");
// const OptimismTreasuryArtifact = require("../../artifacts/contracts/OptimismTreasury.sol/OptimismTreasury.json");
const OwnerRelayOnOptimismArtifact = require("../artifacts/contracts/OwnerRelayOnOptimism.sol/OwnerRelayOnOptimism.json");

// NOTE I put the code for 2 separate calls in this file. both are related to the Optimism bridge
// you will have to comment the top tx related code and uncomment the bottom one to run the bottom method
async function main() {
  const bridgeAddress = "";

  const [deployer] = await ethers.getSigners();
  const ownerRelayOnOptimism = await ethers.getContractAt(
    OwnerRelayOnOptimismArtifact.abi,
    bridgeAddress,
    deployer.signer
  );
  // use OVM_L2CrossDomainMessenger
  // from https://github.com/ethereum-optimism/optimism/blob/ef5343d61708f2d15f51dca981f03ee4ac447c21/packages/contracts/deployments/README.md
  const messengerAddress = "0x4200000000000000000000000000000000000007";
  // TODO step 1 deploy optimism relay, step 2 deploy ethereum relay, step 3 paste the address, step 4 run this script
  const relayOnEthereum = "";

  const tx = await ownerRelayOnOptimism.setContractData(
    messengerAddress,
    relayOnEthereum
  );
  console.log("tx submitted", tx);

  // TODO work on testing direct relay as well
  // const optimismTreasuryAddress = "";
  // const optimismTreasury = await ethers.getContractAt(
  //   OptimismTreasuryArtifact.abi,
  //   optimismTreasuryAddress,
  //   signer
  // );
  // const tokenToTransferAddress = "";
  // const transferTo = "";
  // const transferAmount = ethers.utils.parseEther(1);
  // const transferPayload = optimismTreasury.interface.encodeFunctionData(
  //   "transferToken(address,address,uint256)",
  //   [tokenToTransferAddress, transferTo, transferAmount]
  // );
  // const tx = await ownerRelayOnOptimism.directRelay(
  //   optimismTreasuryAddress,
  //   transferPayload
  // );
  // console.log("tx submitted", tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
