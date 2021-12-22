const fs = require("fs");
const { web3, ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const distributionAddresses = require("./helpers/dist-addresses.json");

const setTargetAddress = (contractName, network, address) => {
  distributionAddresses[network][contractName] = address;
  fs.writeFileSync(
    "./scripts/helpers/dist-addresses.json",
    JSON.stringify(distributionAddresses),
    function (err) {
      if (err) return console.log(err);
    }
  );
};

const getTargetAddress = (contractName, network) => {
  return distributionAddresses[network][contractName];
};

let historicalSnapshot = require("./helpers/staking-data.json");

async function distributionSetup() {
  const accounts = await ethers.getSigners();
  const networkObj = await ethers.provider.getNetwork();
  let network = networkObj.chainId === 10 ? "optimism" : networkObj.name;

  if (network !== "optimism") {
    console.log("using test snapshot");
    historicalSnapshot = require("./helpers/staking-test-data.json");
  }
  console.log("Network name:" + network);

  const owner = accounts[0];

  const historicalSnapshotData = Object.entries(historicalSnapshot);

  const userBalanceAndHashes = [];
  const userBalanceHashes = [];
  const totalStakingScore = historicalSnapshotData.reduce(
    (acc, [, stakingScore]) => acc + stakingScore,
    0
  );

  const FLOOR_AMOUNT = 0.001 * 1e18;
  const totalFloorDistribution =
    Object.keys(historicalSnapshotData).length * FLOOR_AMOUNT;

  const DISTRIBUTION_AMOUNT = 765306122448979591836;
  const POST_FLOOR_DISTRIBUTION_AMOUNT =
    DISTRIBUTION_AMOUNT - totalFloorDistribution;

  const aelinAmounts = {};
  const vAelinAmounts = {};
  let totalAelinAmount = 0;
  let totalVAelinAmount = 0;

  // merge all addresses into final snapshot
  // get list of leaves for the merkle trees using index, address and token balance
  // encode user address and balance using web3 encodePacked
  let duplicateCheckerSet = new Set();
  let i = 0;
  for (const [address, stakingScore] of historicalSnapshotData) {
    // new value is stakingScore / totalStakingScore * DISTRIBUTION_AMOUNT
    let newValue =
      Math.round(
        POST_FLOOR_DISTRIBUTION_AMOUNT * (stakingScore / totalStakingScore)
      ) + FLOOR_AMOUNT;

    if (
      address.toLowerCase() ===
      "0x8cA24021E3Ee3B5c241BBfcee0712554D7Dc38a1".toLowerCase()
    ) {
      console.log("DISTRIBUTION_AMOUNT", DISTRIBUTION_AMOUNT);
      console.log("totalVAelinAmount", totalVAelinAmount);
      // fix js precision loss by taking tiny tiny amount away from largest holder
      newValue = DISTRIBUTION_AMOUNT - totalVAelinAmount;
    }

    aelinAmounts[address] = Math.round((newValue * 98) / 100);
    totalAelinAmount += aelinAmounts[address];
    vAelinAmounts[address] = Math.round(newValue);
    totalVAelinAmount += vAelinAmounts[address];

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

  console.log("totalAelinAmount", totalAelinAmount);
  console.log("totalVAelinAmount", totalVAelinAmount);

  fs.writeFileSync(
    `./scripts/helpers/vaelin-amounts.json`,
    JSON.stringify(vAelinAmounts),
    function (err) {
      if (err) return console.log(err);
    }
  );

  fs.writeFileSync(
    `./scripts/helpers/aelin-amounts.json`,
    JSON.stringify(aelinAmounts),
    function (err) {
      if (err) return console.log(err);
    }
  );

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
    `./scripts/helpers/${network}/dist-hashes.json`,
    JSON.stringify(userBalanceAndHashes),
    function (err) {
      if (err) return console.log(err);
    }
  );

  // Get tree root
  const root = merkleTree.getHexRoot();
  console.log("tree root:", root);

  const virtualAelinAddress = getTargetAddress("VirtualAelinToken", network);
  console.log("$vAELIN token address:", virtualAelinAddress);

  // deploy Distribution contract
  const Distribution = await ethers.getContractFactory("Distribution");
  const distribution = await Distribution.deploy(
    owner.address,
    virtualAelinAddress,
    root
  );
  await distribution.deployed();

  console.log("distribution deployed at", distribution.address);
  // update dist-addresses.json file
  setTargetAddress("Distribution", network, distribution.address);
}

distributionSetup()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
