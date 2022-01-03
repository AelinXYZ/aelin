const { id } = require("ethers/lib/utils");
const fs = require("fs");

const openRedemptionPeriodTxsToRemove = [
  "0xd036894615103757c454d32b433a3051741271f8434369672b8ac5d84243894a".toLowerCase(), // $1950
  "0xa809d172637e63a2ce5a3217381c12cb7f44d24731d60248642a76eb574866ef".toLowerCase(), // $230
  "0xbbd7f386fc8d92975833ee6a1666f19dcf3a6857a8e35a75f914a40624ef70a9".toLowerCase(), // $1000
  "0x901aea11e9791d2b299c7c4511d0a1b28ecb5aa598f3353139d5cf028c37a202".toLowerCase(), // $1550
  "0x907ee3e8cb03a8a1674b0e70105c17e38959612431af97bb2ed26df7b5309bcd".toLowerCase(), // $7000
  "0x8670b8a4b249a6783258003814f4aec11cc684a0e959e4c868aca5bd61739b47".toLowerCase(), // $17
  "0x9e34a83d91a30af9edbbd9267f60e9b9a4819926a557dc0a6e2817067c05f21d".toLowerCase(), // $5818
  "0x0d9d596715689910f43a0843b8c59b1104f70faf6aeb541888141755949dd3b1".toLowerCase(), // $6718
];

async function main() {
  const claimedData = require("./aelin-pool-claimed.json");
  const accepted = claimedData.data.acceptDeals;
  const scores = {};
  const EXTRA_FROM_ROUNDING = 260000;

  const AELIN_AMOUNT = 250 * 10 ** 18;
  console.log("AELIN_AMOUNT", AELIN_AMOUNT);
  let totalScore = 0;

  console.log("accepted.length", accepted.length);
  for (let i = 0; i < accepted.length; i++) {
    if (
      openRedemptionPeriodTxsToRemove.includes(
        accepted[i].id.split("-")[0].toLowerCase()
      )
    ) {
      console.log("removing this tx");
      continue;
    }
    if (scores[accepted[i].purchaser]) {
      scores[accepted[i].purchaser] += Number(accepted[i].poolTokenAmount);
    } else {
      scores[accepted[i].purchaser] = Number(accepted[i].poolTokenAmount);
    }
    totalScore += Number(accepted[i].poolTokenAmount);
  }

  console.log("totalScore", totalScore);

  const aelinFinal = {};
  let totalAmount = 0;
  const entries = Object.entries(scores);
  entries.forEach(([address, score]) => {
    const aelinAmount = Math.round((score / totalScore) * AELIN_AMOUNT);
    aelinFinal[address] = aelinAmount;
    totalAmount += aelinAmount;
  });

  console.log("totalAmount", totalAmount + EXTRA_FROM_ROUNDING);

  const sortedAelinFinal = [];
  Object.entries(aelinFinal).map(([address, amount]) => {
    sortedAelinFinal.push({
      address,
      amount: Number(amount),
    });
  });

  // need to sort in reverse order so the biggest holder
  sortedAelinFinal.sort((a, b) => b.amount - a.amount);

  const sortedAelinFinalObject = {};
  for (let i = 0; i < sortedAelinFinal.length; i++) {
    sortedAelinFinalObject[sortedAelinFinal[i].address] = Number(
      sortedAelinFinal[i].amount
    );
  }

  // NOTE due to hte use of Math.round() we only had a total of 249999999999999740000
  // therefore we will add a total of 250000000000000000000 - 249999999999999740000 = 260000 AELIN to the smallest investor
  sortedAelinFinalObject[
    sortedAelinFinal[sortedAelinFinal.length - 1].address
  ] += EXTRA_FROM_ROUNDING;
  // smallest holder will now be 8592170269275 + 260000 = 8592170529275

  fs.writeFileSync(
    `./scripts/helpers/aelin-pool-distribution.json`,
    JSON.stringify(sortedAelinFinalObject),
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
