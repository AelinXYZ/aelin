const fs = require("fs");
const hre = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const { web3, ethers } = require("hardhat");
const deployments = require("./deployments.json");

const getTargetAddress = (contractName, network) => {
  return deployments[network][contractName];
};

const setTargetAddress = (contractName, network, address) => {
  deployments[network][contractName] = address;
  fs.writeFileSync(
    "./deployments.json",
    JSON.stringify(deployments),
    function (err) {
      if (err) return console.log(err);
    }
  );
};
let historicalSnapshot = require("./staking-data.json");

async function distributionSetup() {
  const accounts = await ethers.getSigners();
  const networkObj = await ethers.provider.getNetwork();
  let network = networkObj.name;
  if (network === "homestead") {
    network = "mainnet";
  } else if (network === "unknown") {
    network = "localhost";
  }

  if (network !== "mainnet") {
    console.log("not on mainnet - using test snapshot");
    historicalSnapshot = require("./staking-test-data.json");
  }
  console.log("Network name:" + network);

  const owner = accounts[0];

  const AelinToken = await ethers.getContractFactory("AelinToken");
  const aelin = await AelinToken.attach(aelinAddress);
  const totalSupply = await aelin.totalSupply();
  console.log("aelin token total supply", totalSupply);

  const PERCENT_TO_STAKERS = 0.15;
  const DISTRIBUTION_AMOUNT = totalSupply.mul(PERCENT_TO_STAKERS);

  const historicalSnapshotData = Object.entries(historicalSnapshot);

  const userBalanceAndHashes = [];
  const userBalanceHashes = [];
  const totalStakingScore = historicalSnapshotData.reduce(
    (acc, [, stakingScore]) => acc.add(stakingScore),
    new ethers.BigNumber.from(0)
  );

  // merge all addresses into final snapshot
  // get list of leaves for the merkle trees using index, address and token balance
  // encode user address and balance using web3 encodePacked
  let duplicateCheckerSet = new Set();
  let i = 0;
  for (const [address, stakingScore] of historicalSnapshotData) {
    // new value is stakingScore / totalStakingScore * DISTRIBUTION_AMOUNT
    const newValue = stakingScore
      .times(DISTRIBUTION_AMOUNT)
      .div(totalStakingScore)
      .round();

    if (duplicateCheckerSet.has(address)) {
      console.log(
        "duplicate found - this should never happens",
        "address",
        address,
        "skipped stakingScore",
        stakingScore
      );
      throw new Error(
        "duplicate entry found - should not happen or need to update script"
      );
    } else {
      duplicateCheckerSet.add(address);
    }
    const hash = keccak256(web3.utils.encodePacked(i, address, newValue));
    const balance = {
      address: address,
      balance: newValue,
      hash: hash,
      proof: "",
      index: i,
    };
    userBalanceHashes.push(hash);
    userBalanceAndHashes.push(balance);
    i++;
  }

  // create merkle tree
  const merkleTree = new MerkleTree(userBalanceHashes, keccak256, {
    sortLeaves: true,
    sortPairs: true,
  });

  for (const ubh in userBalanceAndHashes) {
    userBalanceAndHashes[ubh].proof = merkleTree.getHexProof(
      userBalanceAndHashes[ubh].hash
    );
  }
  fs.writeFileSync(
    `./${network}/distribution-hashes.json`,
    JSON.stringify(userBalanceAndHashes),
    function (err) {
      if (err) return console.log(err);
    }
  );

  // Get tree root
  const root = merkleTree.getHexRoot();
  console.log("tree root:", root);

  const aelinAddress = getTargetAddress("Aelin", network);
  console.log("aelin address:", aelinAddress);

  // deploy Distribution contract
  const Distribution = await ethers.getContractFactory("Distribution");
  const distribution = await Distribution.deploy(
    owner.address,
    aelinAddress,
    root
  );
  await distribution.deployed();

  await aelin.transfer(distribution.address, totalStakingScore);

  console.log("distribution deployed at", distribution.address);
  // update deployments.json file
  setTargetAddress("Distribution", network, distribution.address);

  await hre.run("verify:verify", {
    address: distribution.address,
    constructorArguments: [owner.address, aelinAddress, root],
  });
}

distributionSetup()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
