const fs = require('fs');
const csv = require('fast-csv');
const stakingData = require('./staking-data.json');
const ethers = require('ethers');
const chunk = require('lodash/chunk');
const flatten = require('lodash/flatten');

const ARCHIVE_NODE_URL = "";
const ARCHIVE_NODE_USER = "";
const ARCHIVE_NODE_PASS = "";

const SynthetixStateContractAddress =
	"0x4b9Ca5607f1fF8019c1C6A3c2f0CC8de622D5B82";

	const SynthetixContractAddress =
	"0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f";

const SynthetixStateABI = [
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "issuanceData",
		"outputs": [
			{
				"name": "initialDebtOwnership",
				"type": "uint256"
			},
			{
				"name": "debtEntryIndex",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function",
		"signature": "0x8b3f8088"
	},
	];

const SynthetixABI = [{
	"constant": true,
	"inputs": [
		{
			"internalType": "address",
			"name": "account",
			"type": "address"
		}
	],
	"name": "collateral",
	"outputs": [
		{
			"internalType": "uint256",
			"name": "",
			"type": "uint256"
		}
	],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}];

let leftovers = [];


const provider = new ethers.providers.JsonRpcProvider({
	url: ARCHIVE_NODE_URL,
	user: ARCHIVE_NODE_USER,
	password: ARCHIVE_NODE_PASS,
});

const stateContract = new ethers.Contract(
	SynthetixStateContractAddress,
	SynthetixStateABI,
	provider
);

const synthetixContract = new ethers.Contract(
	SynthetixContractAddress,
	SynthetixABI,
	provider
)

const blockNumber = 13812548;

const loadLastDebtLedgerEntry = async (address) => {
  const [issuanceData, collateral] = await Promise.all([stateContract.issuanceData(address,{
    blockTag: blockNumber,
  }), synthetixContract.collateral(address)]);

  return {initialDebtOwnership: issuanceData.initialDebtOwnership, debtEntryIndex: issuanceData.debtEntryIndex, collateral: collateral};
};

const runAllQueries = async(source) => {
  const batches = chunk(source, 50);
  const results = [];
  while (batches.length) {
		const batch = batches.shift();
		console.log('batching');
    const result = await Promise.all(batch.map(({HolderAddress}) => loadLastDebtLedgerEntry(HolderAddress)));
    results.push(result)
  }
	return flatten(results);
}



fs.createReadStream('./etherscan-source.csv')
    .pipe(csv.parse({ headers: true }))
    .on('error', error => console.error(error))
    .on('data', row => {
			if (!stakingData[ethers.utils.getAddress(row.HolderAddress)]) {
				leftovers.push(row)
			}
		})
    .on('end', async(rowCount) => {

			const results = await runAllQueries(leftovers);
			const arr = results.map(({initialDebtOwnership, debtEntryIndex, collateral}, i) => {
				return {
					id: ethers.utils.getAddress(leftovers[i].HolderAddress),
					initialDebtOwnership,
					debtEntryIndex,
					collateral: ethers.utils.formatEther(collateral.toString())
				}
			}).filter(({initialDebtOwnership}) => Number(initialDebtOwnership) > 0);

			console.log(arr.length);
			fs.writeFileSync(
				`./missing-wallets.json`,
				JSON.stringify(arr),
				function (err) {
					if (err) return console.log(err);
				}
			);
		});

