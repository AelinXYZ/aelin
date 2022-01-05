const fs = require("fs");
const { ethers } = require("ethers");

async function main() {
  const finalData = {};
  const firstPoolDistribution = require("./aelin-pool-distribution.json");
  const retroCCPayments = require("./retro-cc.json");
  const missingWalletsUpToDec28 = require("./missed-addresses.json");

  let combinedScore = 0;
  let firstPoolScore = 0;
  // count each one and then sum
  Object.entries(firstPoolDistribution).forEach(([address, amount]) => {
    const formattedAddress = ethers.utils.getAddress(address);
    if (finalData[formattedAddress]) {
      finalData[formattedAddress] += amount;
    } else {
      finalData[formattedAddress] = amount;
    }
    firstPoolScore += amount;
  });
  console.log("firstPoolScore", firstPoolScore);
  combinedScore += firstPoolScore;

  let retroScore = 0;
  Object.entries(retroCCPayments).forEach(([address, amount]) => {
    const formattedAddress = ethers.utils.getAddress(address);
    if (finalData[formattedAddress]) {
      finalData[formattedAddress] += amount;
    } else {
      finalData[formattedAddress] = amount;
    }
    retroScore += amount;
  });
  console.log("retroScore", retroScore);
  combinedScore += retroScore;

  let missingScore = 0;
  Object.entries(missingWalletsUpToDec28).forEach(([address, amount]) => {
    const formattedAddress = ethers.utils.getAddress(address);
    if (finalData[formattedAddress]) {
      finalData[formattedAddress] += amount;
    } else {
      finalData[formattedAddress] = amount;
    }
    missingScore += amount;
  });
  console.log("missingScore", missingScore);
  combinedScore += missingScore;

  console.log("combinedScore", combinedScore);

  let finalTotal = 0;
  Object.entries(finalData).forEach(([, amount]) => {
    finalTotal += amount;
  });

  console.log("final total", finalTotal);
  // count total - make sure it is the same as the combined score

  fs.writeFileSync(
    `./scripts/helpers/second-aelin-distribution.json`,
    JSON.stringify(finalData),
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
