const fs = require("fs");

const previousAmounts = require("./staking-data-without-multisig.json");
const missingWalletScores = require("./final-snx-missing-wallets-scores.json");

async function main() {
  const previousAmountsSorted = previousAmounts.sort(
    (a, b) => a.collateral - b.collateral
  );
  let total = 0;
  let walletCount = 0;
  const finalScores = missingWalletScores.map((data) => {
    const vAELINTarget = previousAmountsSorted.find(
      (oldData) => oldData.collateral > data.collateral
    );
    total += Number(vAELINTarget.vAELIN);
    walletCount += 1;
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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
