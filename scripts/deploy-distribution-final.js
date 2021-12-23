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

let distributionSnapshot = require("./helpers/vaelin-amounts.json");

async function distributionSetup() {
  const accounts = await ethers.getSigners();
  const networkObj = await ethers.provider.getNetwork();
  let network = networkObj.chainId === 10 ? "optimism" : networkObj.name;

  console.log("Network name:" + network);

  const owner = accounts[0];

  const historicalSnapshotData = Object.entries(distributionSnapshot);

  const userBalanceAndHashes = [];
  const userBalanceHashes = [];

  // merge all addresses into final snapshot
  // get list of leaves for the merkle trees using index, address and token balance
  // encode user address and balance using web3 encodePacked
  let duplicateCheckerSet = new Set();
  let i = 0;
  for (const [address, stakingScore] of historicalSnapshotData) {
    // loop over real numbers and then also check how Thales did it

    if (duplicateCheckerSet.has(address)) {
      console.log(
        "duplicate found - this should never happens",
        "address",
        address
      );
      throw new Error(
        "duplicate entry found - should not happen or need to update script"
      );
    } else {
      duplicateCheckerSet.add(address);
    }

    const hash = keccak256(
      web3.utils.encodePacked(i, address.toLowerCase(), stakingScore.toString())
    );
    const balance = {
      address: address.toLowerCase(),
      balance: stakingScore.toString(),
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
}

distributionSetup()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
