const { ethers } = require("hardhat");
const OptimismTreasuryArtifact = require("../artifacts/contracts/OptimismTreasury.sol/OptimismTreasury.json");
const OwnerRelayOnOptimismArtifact = require("../artifacts/contracts/OwnerRelayOnOptimism.sol/OwnerRelayOnOptimism.json");

async function main() {
  const bridgeAddress = "0x88FdC711EFF5877B464D299C7ac3077135C6C5ca";

  const [deployer] = await ethers.getSigners();
  const ownerRelayOnOptimism = await ethers.getContractAt(
    OwnerRelayOnOptimismArtifact.abi,
    bridgeAddress
  );

  const optimismTreasuryAddress = "0x55c1688587e6DfD52E44BF8B7028a8f7525296E7";
  const optimismTreasury = await ethers.getContractAt(
    OptimismTreasuryArtifact.abi,
    optimismTreasuryAddress
  );
  const tokenToTransferAddress = "0xFa0DE0E65292C12ED22c80dA331CA2806a84215D";
  const transferTo = "0x7856f2a12A7A18b4A115d295F548434a9b078fA1";
  const transferAmount = ethers.utils.parseEther("1");
  const transferPayload = optimismTreasury.interface.encodeFunctionData(
    "transferToken(address,address,uint256)",
    [tokenToTransferAddress, transferTo, transferAmount]
  );
  const tx = await ownerRelayOnOptimism
    .connect(deployer)
    .directRelay(optimismTreasuryAddress, transferPayload);
  console.log("tx submitted", tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
