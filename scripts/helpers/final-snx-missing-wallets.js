const fs = require('fs');
const ethers = require('ethers');
const chunk = require('lodash/chunk');
const flatten = require('lodash/flatten');

const sourceWallets = require('./final-snx-missing-wallets-data.json');
const firstDistributionList = require('./merkle-data-without-multisig.json');
const missedAddresses = require('./missed-addresses.json');

const SNAPSHOT_L1 = 13812548;
const SNAPSHOT_L2 = 1231112;

const SNX_PRICE_AT_SNAPSHOT = 5.17;

const ARCHIVE_NODE_URL = 'https://ethnode.synthetix.io';
const ARCHIVE_NODE_USER = 'snx';
const ARCHIVE_NODE_PASS = 'snx321';

const SynthetixStateContractAddressL1 = '0x4b9Ca5607f1fF8019c1C6A3c2f0CC8de622D5B82';
const SynthetixStateContractAddressL2 = '0x9770239D49Db97E77fc5Adcb5413654C9e45A510';
const SynthetixContractAddressL1 = '0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f';
const SynthetixContractAddressL2 = '0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4';

const SynthetixStateABI = [
	{
		constant: true,
		inputs: [
			{
				name: '',
				type: 'address',
			},
		],
		name: 'issuanceData',
		outputs: [
			{
				name: 'initialDebtOwnership',
				type: 'uint256',
			},
			{
				name: 'debtEntryIndex',
				type: 'uint256',
			},
		],
		payable: false,
		stateMutability: 'view',
		type: 'function',
		signature: '0x8b3f8088',
	},
];

const SynthetixABI = [
	{
		constant: true,
		inputs: [
			{
				internalType: 'address',
				name: 'account',
				type: 'address',
			},
		],
		name: 'collateral',
		outputs: [
			{
				internalType: 'uint256',
				name: '',
				type: 'uint256',
			},
		],
		payable: false,
		stateMutability: 'view',
		type: 'function',
	},
];

const providerL1 = new ethers.providers.JsonRpcProvider({
	url: ARCHIVE_NODE_URL,
	user: ARCHIVE_NODE_USER,
	password: ARCHIVE_NODE_PASS,
});
const providerL2 = new ethers.providers.JsonRpcProvider(
	'https://optimism-mainnet.infura.io/v3/018f3cd9ce7a4195907762b9da21e859'
);

const stateContractL1 = new ethers.Contract(
	SynthetixStateContractAddressL1,
	SynthetixStateABI,
	providerL1
);
const stateContractL2 = new ethers.Contract(
	SynthetixStateContractAddressL2,
	SynthetixStateABI,
	providerL2
);

const synthetixContractL1 = new ethers.Contract(
	SynthetixContractAddressL1,
	SynthetixABI,
	providerL1
);
const synthetixContractL2 = new ethers.Contract(
	SynthetixContractAddressL2,
	SynthetixABI,
	providerL2
);

const connectors = {
	L1: {
		provider: providerL1,
		stateContract: stateContractL1,
		synthetixContract: synthetixContractL1,
		snapshot: SNAPSHOT_L1,
	},
	L2: {
		provider: providerL2,
		stateContract: stateContractL2,
		synthetixContract: synthetixContractL2,
		snapshot: SNAPSHOT_L2,
	},
};

const loadTotalDebtL1 = async () => {
	const contract = new ethers.Contract(
		'0x9D5551Cd3425Dd4585c3E7Eb7E4B98902222521E',
		['function currentDebt() view returns (uint256 debt, bool anyRateIsInvalid)'],
		providerL1
	);

	const currentDebtObject = await contract.currentDebt({
		blockTag: SNAPSHOT_L1,
	});

	return Number(currentDebtObject.debt) / 1e18;
};

const getDebtDataForAddress = async (address, layer) => {
	const { stateContract, synthetixContract, snapshot } = connectors[layer];
	const [issuanceData, collateral] = await Promise.all([
		stateContract.issuanceData(address, {
			blockTag: snapshot,
		}),
		synthetixContract.collateral(address, { blockTag: snapshot }),
	]);

	return {
		address: ethers.utils.getAddress(address),
		initialDebtOwnership: issuanceData.initialDebtOwnership / 1e18,
		debtEntryAtIndex: issuanceData.debtEntryIndex / 1e18,
		collateral: collateral / 1e18,
	};
};

const runAllQueries = async (source, layer) => {
	const batches = chunk(source, 50);
	const results = [];
	while (batches.length) {
		const batch = batches.shift();
		console.log('batching');
		const result = await Promise.all(
			batch.map((walletAddress) => getDebtDataForAddress(walletAddress, layer))
		);
		results.push(result);
	}
	return flatten(results);
};

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

	const ownershipPercentOfTotalDebt = cappedCurrentDebtBalance / totalDebtInSystem;

	return Number(ownershipPercentOfTotalDebt) * 10 ** 8;
};

const loadLastDebtLedgerEntry = async () => {
	const contract = new ethers.Contract(
		SynthetixStateContractAddressL1,
		['function lastDebtLedgerEntry() view returns (uint256)'],
		providerL1
	);
	const lastDebtLedgerEntry = await contract.lastDebtLedgerEntry({
		blockTag: SNAPSHOT_L1,
	});

	return ethers.utils.formatUnits(lastDebtLedgerEntry, 27);
};

const run = async () => {
	console.log(`Number of wallets from initial list: ${Object.keys(sourceWallets).length}`);
	const filteredSourceWallets = Object.keys(sourceWallets).filter(
		(key) => !missedAddresses[key] && !firstDistributionList[key]
	);
	console.log(
		`Number of wallets which were not already part of the distribution : ${filteredSourceWallets.length}`
	);
	const eligibleWalletsL1 = (await runAllQueries(filteredSourceWallets, 'L1')).filter(
		({ initialDebtOwnership, collateral }) =>
			Number(initialDebtOwnership) > 0 && Number(collateral) > 1
	);
	const eligibleWalletsL2 = (await runAllQueries(filteredSourceWallets, 'L2')).filter(
		({ initialDebtOwnership, collateral }) =>
			Number(initialDebtOwnership) > 0 && Number(collateral) > 1
	);
	console.log(`Eligible wallets for L1: ${eligibleWalletsL1.length}`);
	console.log(`Eligible wallets for L2: ${eligibleWalletsL2.length}`);

	const totalDebtL1 = await loadTotalDebtL1();
	const totalL2Debt = Number('44623051603213924679706746') / 1e18;

	const lastDebtLedgerEntryL1 = await loadLastDebtLedgerEntry();
	const lastDebtLedgerEntryL2 = '10432172923357179928181650' / 1e27;

	const normalisedL2CRatio = 500 / 400;
	const scaledTotalL2Debt = totalL2Debt * normalisedL2CRatio;

	const issuanceRatioL1 = 0.25;
	const issuanceRatioL2 = 0.2;

	let output = {};
	for (let i = 0; i < eligibleWalletsL1.length; i++) {
		const holder = eligibleWalletsL1[i];
		const vote = computeScaledWeight(
			holder.initialDebtOwnership,
			holder.debtEntryAtIndex,
			totalDebtL1,
			scaledTotalL2Debt,
			lastDebtLedgerEntryL1,
			holder.collateral,
			issuanceRatioL1,
			false
		);

		if (output[ethers.utils.getAddress(holder.address)]) {
			console.log('should never have a duplicate in L1 results but we do with:', holder.address);
			output[ethers.utils.getAddress(holder.address)].score += vote;
			output[ethers.utils.getAddress(holder.address)].collateral += Number(holder.collateral);
		} else {
			output[ethers.utils.getAddress(holder.address)] = {
				score: vote,
				collateral: Number(holder.collateral),
			};
		}
	}
	for (let i = 0; i < eligibleWalletsL2.length; i++) {
		const holder = eligibleWalletsL2[i];
		const vote = computeScaledWeight(
			holder.initialDebtOwnership,
			holder.debtEntryAtIndex,
			totalDebtL1,
			scaledTotalL2Debt,
			lastDebtLedgerEntryL2,
			holder.collateral,
			issuanceRatioL2,
			true
		);

		if (output[ethers.utils.getAddress(holder.address)]) {
			console.log('should never have a duplicate in L1 results but we do with:', holder.address);
			output[ethers.utils.getAddress(holder.address)].score += vote;
			output[ethers.utils.getAddress(holder.address)].collateral += Number(holder.collateral);
		} else {
			output[ethers.utils.getAddress(holder.address)] = {
				score: vote,
				collateral: Number(holder.collateral),
			};
		}
	}
	const accountsValues = [];
	Object.entries(output).map(([address, { score, collateral }]) => {
		accountsValues.push({
			address,
			score,
			collateral,
		});
	});
	accountsValues.sort((a, b) => a.score - b.score);
	fs.writeFileSync(
		`./scripts/helpers/final-snx-missing-wallets-scores.json`,
		JSON.stringify(accountsValues),
		function (err) {
			if (err) return console.log(err);
		}
	);
};

run();
