const fs = require("fs");
const { web3, ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const distributionAddresses = require("./helpers/dist-addresses.json");

const setTargetAddress = (contractName, network, address) => {
  distributionAddresses[network][contractName] = address;
  fs.writeFileSync(
    "./dist-addresses.json",
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
  let network = networkObj.name;

  if (network !== "optimism") {
    console.log("not on prod - using test snapshot");
    historicalSnapshot = require("./helpers/staking-test-data.json");
  }
  console.log("Network name:" + network);

  const owner = accounts[0];

  const AELIN_FEE = 0.02;

  const AELIN_AIRDROP_AMOUNT = 750;
  // to account for the 2% protocol fee;
  const vAELIN_AIRDROP_AMOUNT = AELIN_AIRDROP_AMOUNT / (1 - AELIN_FEE);

  const DISTRIBUTION_AMOUNT = ethers.utils.parseUnits(
    vAELIN_AIRDROP_AMOUNT.toString(),
    18
  );

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
    console.log("address", address, "stakingScore", stakingScore);
    // new value is stakingScore / totalStakingScore * DISTRIBUTION_AMOUNT
    const newValue = new ethers.BigNumber.from(stakingScore)
      .mul(DISTRIBUTION_AMOUNT)
      .div(totalStakingScore);

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

  // TODO figure out what config is needed for this to work properly
  // await hre.run("verify:verify", {
  //   address: distribution.address,
  //   constructorArguments: [owner.address, virtualAelinAddress, root],
  // });
}

distributionSetup()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
