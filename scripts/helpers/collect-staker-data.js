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


const ARCHIVE_NODE_URL= '';
const ARCHIVE_NODE_USER= '';
const ARCHIVE_NODE_PASS= '';

const MAX_LENGTH = 1000;
const HIGH_PRECISE_UNIT = 1e27;
const MED_PRECISE_UNIT = 1e18;

const SNX_PRICE_AT_SNAPSHOT = 5;

const computeScaledWeight =  (
  initialDebtOwnership,
  debtEntryAtIndex,
  totalL1Debt,
  scaledTotalL2Debt,
  lastDebtLedgerEntry,
  collateral,
  targetRatio,
  isL2

) => {

  const totalDebt = isL2 ? scaledTotalL2Debt: totalL1Debt;
  const currentDebtOwnershipPercent =
    (Number(lastDebtLedgerEntry) / Number(debtEntryAtIndex)) *
    Number(initialDebtOwnership);

  const highPrecisionBalance =
  totalDebt *
    MED_PRECISE_UNIT *
    (currentDebtOwnershipPercent / HIGH_PRECISE_UNIT);

  const currentDebtBalance = highPrecisionBalance / MED_PRECISE_UNIT;

  const cappedCurrentDebtBalance = Math.min(currentDebtBalance, Number(collateral) * SNX_PRICE_AT_SNAPSHOT * targetRatio);

  const totalDebtInSystem = totalL1Debt + scaledTotalL2Debt;

  const ownershipPercentOfTotalDebt = cappedCurrentDebtBalance / totalDebtInSystem;

  return ownershipPercentOfTotalDebt;
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
  block
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
    return getSNXHolders(
      blockNumber,
      stakedResponse.snxholders[stakedResponse.snxholders.length - 1].timestamp,
      data,
      numCalls + 1,
      network
    );
  }
  return data;
}

async function main() {
  const score = {};

  const l1Provider = new ethers.providers.JsonRpcProvider({
    url: ARCHIVE_NODE_URL,
    user: ARCHIVE_NODE_USER,
    password: ARCHIVE_NODE_PASS,
  });

  const l1BlockNumber = 13812548;
  const l2BlockNumber = 1231112;

  const l1Results = await getHolders(l1BlockNumber, "L1");
  const l2Results = await getHolders(l2BlockNumber, "L2");

  const totalL1Debt = await loadTotalDebt(l1Provider, l1BlockNumber); // (high-precision 1e18)
  const totalL2Debt = Number('44623051603213924679706746') / 1e18;

  const lastDebtLedgerEntryL1 = await loadLastDebtLedgerEntry(
    l1Provider,
    l1BlockNumber
  );
  const lastDebtLedgerEntryL2 = Number('10432172923357179928181650') / 1e18;

  const issuanceRatioL1 = 0.25;
  const issuanceRatioL2 = 0.2;

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
      const vote = computeScaledWeight(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL1,
        holder.collateral,
        issuanceRatioL1,
        false,
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
      const vote = computeScaledWeight(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL2,
        holder.collateral,
        issuanceRatioL2,
        true
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
