const fs = require("fs");

const previousAmounts = require("./staking-data-without-multisig.json");
const missingWalletScores = require("./final-snx-missing-wallets-scores.json");

async function main() {
  const previousAmountsSorted = previousAmounts.sort(
    (a, b) => a.collateral - b.collateral
  );
  let total = 0;
  let walletCount = 0;
  let finalOutput = {};
  const finalScores = missingWalletScores.map((data) => {
    const vAELINTarget = previousAmountsSorted.find(
      (oldData) => oldData.collateral > data.collateral
    );
    if (data.address === "0x581e0F4638A7c8Be735879275B1d47Be09E80d14") {
      vAELINTarget.vAELIN = "0.002608592133224029";
    }
    total += Number(vAELINTarget.vAELIN);
    walletCount += 1;
    finalOutput[data.address] = vAELINTarget.vAELIN;
    return {
      ...data,
      vAELIN: vAELINTarget.vAELIN,
    };
  });

  console.log("total vAELIN", total);
  console.log("walletCount", walletCount);

  fs.writeFileSync(
    `./scripts/helpers/final-snx-missing-wallets-amounts.json`,
    JSON.stringify(finalScores),
    function (err) {
      if (err) return console.log(err);
    }
  );

  fs.writeFileSync(
    `./scripts/helpers/final-snx-missing-wallets-amounts-output.json`,
    JSON.stringify(finalOutput),
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
