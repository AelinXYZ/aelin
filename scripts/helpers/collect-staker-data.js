const fs = require("fs");
const { request, gql } = require("graphql-request");
const { ethers } = require("ethers");
const { getAddress } = require("@ethersproject/address");

const DebtCacheABI = [
  "function currentDebt() view returns (uint256 debt, bool anyRateIsInvalid)",
];

const SynthetixStateABI = [
  "function lastDebtLedgerEntry() view returns (uint256)",
];

// @TODO: check if most-up-to-date version (using https://contracts.synthetix.io/SynthetixState)
const SynthetixStateContractAddress =
  "0x4b9Ca5607f1fF8019c1C6A3c2f0CC8de622D5B82";
// @TODO: check if most-up-to-date version (using http://contracts.synthetix.io/DebtCache)
const DebtCacheContractAddress = "0x9D5551Cd3425Dd4585c3E7Eb7E4B98902222521E";

const synthetixSnxL1 =
  "https://api.thegraph.com/subgraphs/name/synthetixio-team/synthetix";
const synthetixSnxL2 =
  "https://api.thegraph.com/subgraphs/name/synthetixio-team/optimism-main";

const MAX_LENGTH = 1000;
const HIGH_PRECISE_UNIT = 1e27;
const MED_PRECISE_UNIT = 1e18;
const SCALING_FACTOR = 1e5;

const debtL1 = async (
  initialDebtOwnership,
  debtEntryAtIndex,
  totalL1Debt,
  scaledTotalL2Debt,
  lastDebtLedgerEntry
) => {
  const currentDebtOwnershipPercent =
    (Number(lastDebtLedgerEntry) / Number(debtEntryAtIndex)) *
    Number(initialDebtOwnership);

  const highPrecisionBalance =
    totalL1Debt *
    MED_PRECISE_UNIT *
    (currentDebtOwnershipPercent / HIGH_PRECISE_UNIT);

  const currentDebtBalance = highPrecisionBalance / MED_PRECISE_UNIT;

  const totalDebtInSystem = totalL1Debt + scaledTotalL2Debt;

  const ownershipPercentOfTotalDebt = currentDebtBalance / totalDebtInSystem;

  const scaledWeighting = ownershipPercentOfTotalDebt * SCALING_FACTOR;

  return scaledWeighting;
};

const debtL2 = async (
  initialDebtOwnership,
  debtEntryAtIndex,
  totalL1Debt,
  scaledTotalL2Debt,
  lastDebtLedgerEntryL2
) => {
  const currentDebtOwnershipPercent =
    (Number(lastDebtLedgerEntryL2) / Number(debtEntryAtIndex)) *
    Number(initialDebtOwnership);

  const highPrecisionBalance =
    totalL1Debt *
    MED_PRECISE_UNIT *
    (currentDebtOwnershipPercent / HIGH_PRECISE_UNIT);

  const currentDebtBalance = highPrecisionBalance / MED_PRECISE_UNIT;

  const totalDebtInSystem = totalL1Debt + scaledTotalL2Debt;

  const ownershipPercentOfTotalDebt = currentDebtBalance / totalDebtInSystem;

  const scaledWeighting = ownershipPercentOfTotalDebt * SCALING_FACTOR;

  return scaledWeighting;
};

const loadLastDebtLedgerEntry = async (provider, snapshot) => {
  const contract = new ethers.Contract(
    SynthetixStateContractAddress,
    SynthetixStateABI,
    provider
  );

  const lastDebtLedgerEntry = await contract.lastDebtLedgerEntry({
    blockTag: snapshot,
  });

  return ethers.BigNumber.from(lastDebtLedgerEntry);
};

const loadTotalDebt = async (provider, snapshot) => {
  const contract = new ethers.Contract(
    DebtCacheContractAddress,
    DebtCacheABI,
    provider
  );

  const currentDebtObject = await contract.currentDebt({
    blockTag: snapshot,
  });

  return Number(currentDebtObject.debt) / MED_PRECISE_UNIT;
};

const createStakersQuery = (blockNumber, minTimestamp) => {
  const minTimestampWhere =
    minTimestamp != null ? `, timestamp_lt: $minTimestamp` : "";
  return gql`
query snxholders($minInitialDebtOwnership: Int!, $minTimestamp: String) {
snxholders(
  first: 1000
  block: { number: ${blockNumber} }
  where: { initialDebtOwnership_gt: $minInitialDebtOwnership${minTimestampWhere} }
  orderBy: timestamp
  orderDirection: desc
) {
  id
  timestamp
  collateral
  debtEntryAtIndex
  initialDebtOwnership
}
}
`;
};

async function getHolders(blockNumber, network) {
  return getSNXHolders(blockNumber, null, [], 0, network);
}

async function getSNXHolders(
  blockNumber,
  minTimestamp = null,
  prevData = [],
  numCalls = 0,
  network
) {
  const stakedResponse = await request(
    network === "L1" ? synthetixSnxL1 : synthetixSnxL2,
    createStakersQuery(blockNumber, minTimestamp),
    {
      minInitialDebtOwnership: 0,
      minTimestamp,
    }
  );
  const data = [...stakedResponse.snxholders, ...prevData];
  if (stakedResponse.snxholders.length === MAX_LENGTH) {
    return getHolders(
      blockNumber,
      stakedResponse.snxholders[stakedResponse.snxholders.length - 1].timestamp,
      data,
      numCalls + 1,
      network
    );
  }
  return;
}

async function main() {
  const l1Provider = new ethers.providers.JsonRpcProvider({
    url: process.env.ARCHIVE_NODE_URL,
    user: process.env.ARCHIVE_NODE_USER,
    password: process.env.ARCHIVE_NODE_PASS,
  });
  const l2Provider = null;
  const score = {};
  const l1BlockNumber = 13812549;
  const l2BlockNumber = 1231113;
  const l1Results = await getHolders(l1BlockNumber, "L1");
  const l2Results = await getHolders(l2BlockNumber, "L2");
  const totalL1Debt = await loadTotalDebt(l1Provider, l1BlockNumber); // (high-precision 1e18)
  const lastDebtLedgerEntryL1 = await loadLastDebtLedgerEntry(
    l1Provider,
    l1BlockNumber
  );
  const lastDebtLedgerEntryL2 = await loadLastDebtLedgerEntry(
    l2Provider,
    l2BlockNumber
  );

  const totalL2Debt = await loadTotalDebt(l2Provider, l2BlockNumber);

  // @TODO update the currentDebt for the snapshot from (https://contracts.synthetix.io/ovm/DebtCache)
  // const totalL2Debt = 48646913;
  // @TODO update the lastDebtLedgerEntry from (https://contracts.synthetix.io/ovm/SynthetixState)
  // const lastDebtLedgerEntryL2 = 9773647546760863848975891;
  // @TODO update the comparison between OVM:ETH c-ratios at the time of snapshot
  const normalisedL2CRatio = 500 / 400;

  const scaledTotalL2Debt = totalL2Debt * normalisedL2CRatio;

  if (l1Results.length > 0 && l2Results.length > 0) {
    for (let i = 0; i < l1Results.length; i++) {
      const holder = l1Results[i];
      const vote = debtL1(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL1
      );
      if (score[getAddress(holder.id)]) {
        console.log(
          "should never have a duplicate in L1 results but we do with:",
          holder.id
        );
        score[getAddress(holder.id)] += vote;
      } else {
        score[getAddress(holder.id)] = vote;
      }
    }
    for (let i = 0; i < l2Results.length; i++) {
      const holder = l2Results[i];
      const vote = await debtL2(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL2
      );
      if (score[getAddress(holder.id)]) {
        console.log("We have a duplicate in L2 results for:", holder.id);
        score[getAddress(holder.id)] += vote;
      } else {
        score[getAddress(holder.id)] = vote;
      }
    }
  } else {
    throw new Error("not getting results from both networks");
  }
  fs.writeFileSync(
    `./staking-data.json`,
    JSON.stringify(score),
    function (err) {
      if (err) return console.log(err);
    }
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
