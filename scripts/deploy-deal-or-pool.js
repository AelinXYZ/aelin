const { ethers } = require("hardhat");
const Create2FactoryArtifact = require("../artifacts/contracts/Create2Factory.sol/Create2Factory.json");
const AelinDealArtifact = require("../FixedCompileAelinDeal.sol/AelinDeal.json");
const AelinPoolArtifact = require("../FixedCompileAelinPool.sol/AelinPool.json");
const { salt } = require("../scripts/constants");

// NOTE each time you udpate the deal you will only be able to deploy it once
// as the deployed contract address is deterministic
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  if (process.env.DEVELOPMENT) {
    console.log("local network dev mode");
    // in development hardhat sets the block gas limit too low at only 3M
    await ethers.provider.send("evm_setBlockGasLimit", [
      `0x${ethers.BigNumber.from(6000000)}`,
    ]);
    await ethers.provider.send("evm_mine", []);
  }

  const create2Factory = await ethers.getContractAt(
    Create2FactoryArtifact.abi,
    process.env.CREATE2
  );

  await create2Factory
    .connect(deployer)
    .deploy(
      process.env.TYPE === "DEAL"
        ? AelinDealArtifact.bytecode
        : AelinPoolArtifact.bytecode,
      salt
    );

  const dealDeployedLogs = await create2Factory.queryFilter(
    create2Factory.filters.Deployed()
  );

  console.log(
    `deterministic ${process.env.TYPE} address:`,
    dealDeployedLogs[dealDeployedLogs.length - 1].args.addr
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
