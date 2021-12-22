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

const ARCHIVE_NODE_URL = "https://ethnode.synthetix.io";
const ARCHIVE_NODE_USER = "snx";
const ARCHIVE_NODE_PASS = "snx321";

const MAX_LENGTH = 1000;

const SNX_PRICE_AT_SNAPSHOT = 5;

const computeScaledWeight = (
  initialDebtOwnership,
  debtEntryAtIndex,
  totalL1Debt,
  scaledTotalL2Debt,
  lastDebtLedgerEntry,
  collateral,
  targetRatio,
  isL2,
  shouldLog
) => {
  const totalDebt = isL2 ? scaledTotalL2Debt : totalL1Debt;

  const debtBalance =
    ((totalDebt * Number(lastDebtLedgerEntry)) / Number(debtEntryAtIndex)) *
    Number(initialDebtOwnership);

  const cappedCurrentDebtBalance = Math.min(
    debtBalance,
    Number(collateral) * SNX_PRICE_AT_SNAPSHOT * targetRatio
  );

  const totalDebtInSystem = totalL1Debt + scaledTotalL2Debt;

  const ownershipPercentOfTotalDebt =
    cappedCurrentDebtBalance / totalDebtInSystem;

  if (shouldLog) {
    console.log("totalDebt", totalDebt);
    console.log("debtBalance", debtBalance);
    console.log("cappedCurrentDebtBalance", cappedCurrentDebtBalance);
    console.log("totalDebtInSystem", totalDebtInSystem);
    console.log("ownershipPercentOfTotalDebt", ownershipPercentOfTotalDebt);
  }

  return ownershipPercentOfTotalDebt * 10 ** 8;
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

  return ethers.utils.formatUnits(lastDebtLedgerEntry, 27);
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

  return Number(currentDebtObject.debt) / 1e18;
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
  const parsedData = stakedResponse.snxholders.map((holder) => {
    holder.initialDebtOwnership = ethers.utils.formatEther(
      holder.initialDebtOwnership
    );
    holder.debtEntryAtIndex = ethers.utils.formatEther(holder.debtEntryAtIndex);
    return holder;
  });
  const data = [...parsedData, ...prevData];
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
  const totalL2Debt = Number("44623051603213924679706746") / 1e18;
  console.log("totalL1Debt", totalL1Debt);
  console.log("totalL2Debt", totalL2Debt);

  const lastDebtLedgerEntryL1 = await loadLastDebtLedgerEntry(
    l1Provider,
    l1BlockNumber
  );
  const lastDebtLedgerEntryL2 = "10432172923357179928181650" / 1e27;
  console.log("lastDebtLedgerEntryL1", lastDebtLedgerEntryL1);
  console.log("lastDebtLedgerEntryL2", lastDebtLedgerEntryL2);
  const issuanceRatioL1 = 0.25;
  const issuanceRatioL2 = 0.2;

  // @TODO update the currentDebt for the snapshot from (https://contracts.synthetix.io/ovm/DebtCache)
  // const totalL2Debt = 48646913;
  // @TODO update the lastDebtLedgerEntry from (https://contracts.synthetix.io/ovm/SynthetixState)
  // const lastDebtLedgerEntryL2 = 9773647546760863848975891;
  // @TODO update the comparison between OVM:ETH c-ratios at the time of snapshot
  const normalisedL2CRatio = 500 / 400;
  const scaledTotalL2Debt = totalL2Debt * normalisedL2CRatio;
  console.log("scaledTotalL2Debt", scaledTotalL2Debt);
  let totalScore = 0;

  if (l1Results.length > 0 && l2Results.length > 0) {
    for (let i = 0; i < l1Results.length; i++) {
      const holder = l1Results[i];
      if (
        holder.id.toLowerCase() ===
        "0xe0041ea9c685fd159e7cb45adf6119ae791f3c93".toLowerCase()
      ) {
        console.log("test holder l1", holder);
      }
      const vote = computeScaledWeight(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL1,
        holder.collateral,
        issuanceRatioL1,
        false,
        holder.id.toLowerCase() ===
          "0xe0041ea9c685fd159e7cb45adf6119ae791f3c93".toLowerCase()
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
      totalScore += vote;
    }
    for (let i = 0; i < l2Results.length; i++) {
      const holder = l2Results[i];
      if (
        holder.id.toLowerCase() ===
        "0xe0041ea9c685fd159e7cb45adf6119ae791f3c93".toLowerCase()
      ) {
        console.log("test holder l2", holder);
      }
      const vote = computeScaledWeight(
        holder.initialDebtOwnership,
        holder.debtEntryAtIndex,
        totalL1Debt,
        scaledTotalL2Debt,
        lastDebtLedgerEntryL2,
        holder.collateral,
        issuanceRatioL2,
        true,
        holder.id.toLowerCase() ===
          "0xe0041ea9c685fd159e7cb45adf6119ae791f3c93".toLowerCase()
      );
      if (score[getAddress(holder.id)]) {
        console.log("We have a duplicate in L2 results for:", holder.id);
        score[getAddress(holder.id)] += vote;
      } else {
        score[getAddress(holder.id)] = vote;
      }
      totalScore += vote;
    }
  } else {
    throw new Error("not getting results from both networks");
  }
  console.log("totalScore is:", totalScore);
  fs.writeFileSync(
    `./scripts/helpers/staking-data.json`,
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
