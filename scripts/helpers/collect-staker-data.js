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
  isL2
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

  return Number(ownershipPercentOfTotalDebt) * 10 ** 8;
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
query snxholders($minCollateral: Int!, $minInitialDebtOwnership: Int!, $minTimestamp: String) {
snxholders(
  first: 1000
  block: { number: ${blockNumber} }
  where: { collateral_gt: $minCollateral, initialDebtOwnership_gt: $minInitialDebtOwnership${minTimestampWhere} }
  orderBy: timestamp
  orderDirection: desc
) {
  id
  timestamp
  collateral
  debtEntryAtIndex
  initialDebtOwnership
  block
  balanceOf
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
      minCollateral: 1,
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
  const readableOutput = {};
  const merkleOutput = {};
  const missingGraphData = require("./missing-wallets.json");
  const parsedMissingGraphData = missingGraphData.map((holder) => {
    holder.initialDebtOwnership = ethers.utils.formatEther(
      ethers.utils.parseEther(
        new ethers.BigNumber.from(holder.initialDebtOwnership).toString()
      )
    );
    holder.debtEntryAtIndex = ethers.utils.formatEther(
      ethers.utils.parseEther(
        new ethers.BigNumber.from(holder.debtEntryIndex).toString()
      )
    );
    return holder;
  });

  const l1Provider = new ethers.providers.JsonRpcProvider({
    url: ARCHIVE_NODE_URL,
    user: ARCHIVE_NODE_USER,
    password: ARCHIVE_NODE_PASS,
  });

  const l1BlockNumber = 13812548;
  const l2BlockNumber = 1231112;

  const l1ResultsGraph = await getHolders(l1BlockNumber, "L1");
  const l1Results = [...l1ResultsGraph, ...parsedMissingGraphData];

  const l2Results = await getHolders(l2BlockNumber, "L2");

  const totalL1Debt = await loadTotalDebt(l1Provider, l1BlockNumber); // (high-precision 1e18)
  const totalL2Debt = Number("44623051603213924679706746") / 1e18;

  const lastDebtLedgerEntryL1 = await loadLastDebtLedgerEntry(
    l1Provider,
    l1BlockNumber
  );
  const lastDebtLedgerEntryL2 = "10432172923357179928181650" / 1e27;

  const issuanceRatioL1 = 0.25;
  const issuanceRatioL2 = 0.2;

  // @TODO update the currentDebt for the snapshot from (https://contracts.synthetix.io/ovm/DebtCache)
  // const totalL2Debt = 48646913;
  // @TODO update the lastDebtLedgerEntry from (https://contracts.synthetix.io/ovm/SynthetixState)
  // const lastDebtLedgerEntryL2 = 9773647546760863848975891;
  // @TODO update the comparison between OVM:ETH c-ratios at the time of snapshot
  const normalisedL2CRatio = 500 / 400;
  const scaledTotalL2Debt = totalL2Debt * normalisedL2CRatio;

  let totalScore = 0;
  let totalCollateral = 0;

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
        false
      );

      if (readableOutput[getAddress(holder.id)]) {
        console.log(
          "should never have a duplicate in L1 results but we do with:",
          holder.id
        );
        readableOutput[getAddress(holder.id)].score += Number(vote);
        readableOutput[getAddress(holder.id)].collateral += Number(
          holder.collateral
        );
      } else {
        readableOutput[getAddress(holder.id)] = {
          score: Number(vote),
          collateral: Number(holder.collateral),
        };
      }
      totalScore += Number(vote);
      totalCollateral += Number(holder.collateral);
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

      if (readableOutput[getAddress(holder.id)]) {
        readableOutput[getAddress(holder.id)].score += Number(vote);
        readableOutput[getAddress(holder.id)].collateral += Number(
          holder.collateral
        );
      } else {
        readableOutput[getAddress(holder.id)] = {
          score: Number(vote),
          collateral: Number(holder.collateral),
        };
      }
      totalScore += Number(vote);
      totalCollateral += Number(holder.collateral);
    }
  } else {
    throw new Error("not getting results from both networks");
  }
  console.log("total score is:", totalScore);
  console.log("total collateral is:", totalCollateral);

  // TODO sort by order of collateral and put into array format temporarily
  const accountsValues = [];
  Object.entries(readableOutput).map(([address, { score, collateral }]) => {
    accountsValues.push({
      address,
      score: Number(score),
      collateral: Number(collateral),
    });
  });

  // need to sort in reverse order so the biggest holder
  accountsValues.sort((a, b) => a.score - b.score);

  // 0.001 / .98 for vAELIN loss
  const FLOOR_AMOUNT = 0.0010204082 * 1e18;
  const totalFloorDistribution = accountsValues.length * FLOOR_AMOUNT;
  console.log("total floor distribution", totalFloorDistribution);
  console.log("FLOOR_AMOUNT", FLOOR_AMOUNT);
  console.log("totalScore", totalScore);

  // NOTE this matches the contract amount of vAELIN exactly
  const DISTRIBUTION_AMOUNT = 765306122448979591836;
  const POST_FLOOR_DISTRIBUTION_AMOUNT =
    DISTRIBUTION_AMOUNT - totalFloorDistribution;

  let totalVAelinAmount = 0;

  console.log("accountsValues.length", accountsValues.length);
  for (let i = 0; i < accountsValues.length; i++) {
    let newValue =
      Math.round(
        POST_FLOOR_DISTRIBUTION_AMOUNT *
          (accountsValues[i].score / Number(totalScore))
      ) + FLOOR_AMOUNT;

    if (i === accountsValues.length - 1) {
      // fix js precision loss by using the difference on the last holder
      // who is the largest whale, taking a tiny tiny tiny amount away from largest holder
      newValue = DISTRIBUTION_AMOUNT - totalVAelinAmount * 1e18;
      merkleOutput[accountsValues[i].address] = newValue;
      accountsValues[i].vAELIN = (newValue / 1e18).toString();
      totalVAelinAmount += Number(accountsValues[i].vAELIN);
    } else {
      merkleOutput[accountsValues[i].address] = newValue;
      accountsValues[i].vAELIN = (Math.round(newValue) / 1e18).toString();
      totalVAelinAmount += Number(accountsValues[i].vAELIN);
    }
  }

  accountsValues.sort((a, b) => b.vAELIN - a.vAELIN);
  console.log("number of distribution recipients", accountsValues.length);
  fs.writeFileSync(
    `./scripts/helpers/staking-data.json`,
    JSON.stringify(accountsValues),
    function (err) {
      if (err) return console.log(err);
    }
  );
  fs.writeFileSync(
    `./scripts/helpers/merkle-data.json`,
    JSON.stringify(merkleOutput),
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
