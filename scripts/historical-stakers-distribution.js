const { request, gql } = require('graphql-request');
const { startOfWeek, eachWeekOfInterval, format } = require('date-fns');
const { Parser } = require('json2csv');
const fs = require('fs');

const DATES = {
	ethereum: {
		2: { start: new Date('02-14-2022'), end: new Date('03-15-2023') },
	},
	optimism: {
		1: { start: new Date('01-10-2022'), end: new Date('03-15-2023') },
		2: { start: new Date('01-17-2022'), end: new Date('03-15-2023') },
	},
};

const GRAPH_URL = {
	optimism: 'https://api.thegraph.com/subgraphs/name/0xcdb/aelin-stakers-optimism',
	ethereum: 'https://api.thegraph.com/subgraphs/name/0xcdb/aelin-stakers-ethereum',
};

function getWeekBlocks(startDate, endDate) {
	const weekTimestamps = [];
	const weekStartDay = 1; // Monday

	// Get an array of all the weeks between the start and end dates
	const weeks = eachWeekOfInterval(
		{ start: startDate, end: endDate },
		{ weekStartsOn: weekStartDay }
	);

	// For each week, add the timestamp of its start to the result array
	weeks.forEach((week) => {
		const weekStart = startOfWeek(week, { weekStartsOn: weekStartDay });
		const weekStartTimestamp = weekStart.getTime();
		weekTimestamps.push(weekStartTimestamp);
	});
	return weekTimestamps;
}

async function getStakersPerBlock(block, network, pool) {
	const first = 1000;
	let skip = 0;
	let allStakers = [];
	const poolName = pool === 1 ? 'poolOne' : 'poolTwo';

	const query = gql`
		query ${poolName}stakers($first: Int!, $skip: Int!) {
			${poolName}Stakers(first: $first, skip: $skip, block: {number: ${block}}) {
				id
				balance
			}
		}
	`;

	// eslint-disable-next-line no-constant-condition
	while (true) {
		const result = await request(GRAPH_URL[network], query, { first, skip });
		const stakers = result[`${poolName}Stakers`];
		allStakers.push(...stakers);
		if (stakers.length < first) {
			break;
		}
		skip += first;
	}
	return allStakers;
}

async function getStakers(network, pool) {
	const first = 1000;
	let skip = 0;
	let totalWallets = [];
	const poolName = pool === 1 ? 'poolOne' : 'poolTwo';

	const query = gql`
		query ${poolName}stakers($first: Int!, $skip: Int!) {
			${poolName}Stakers(first: $first, skip: $skip) {
				id
			}
		}
	`;

	// eslint-disable-next-line no-constant-condition
	while (true) {
		const result = await request(GRAPH_URL[network], query, { first, skip });
		const stakers = result[`${poolName}Stakers`];
		totalWallets.push(...stakers.map((staker) => staker.id));
		if (stakers.length < first) {
			break;
		}
		skip += first;
	}
	return totalWallets;
}

async function fetchAndProcessStakers(network, pool) {
	const weeks = getWeekBlocks(DATES[network][pool].start, DATES[network][pool].end);
	const fields = ['wallet'];
	let stakers = {};

	for await (const week of weeks) {
		const dateFromWeek = format(week, 'dd-MM-yy');
		fields.push(dateFromWeek);
		const timestamp = week / 1000;
		let block = await fetch(`https://coins.llama.fi/block/${network}/${timestamp}`);
		const { height } = await block.json();
		console.log(`PROCESSING BLOCK ${height} for date ${dateFromWeek} `);
		const poolStakersResult = await getStakersPerBlock(height, network, pool);
		stakers[dateFromWeek] = poolStakersResult;
	}

	const sortedWallets = (await getStakers(network, pool)).map((wallet) => {
		let walletRow = { wallet };
		Object.keys(stakers).forEach((week) => {
			const matchWallet = stakers[week].find((staker) => staker.id === wallet);
			if (matchWallet) {
				walletRow = { ...walletRow, [week]: matchWallet.balance / 1e18 };
			} else {
				walletRow = { ...walletRow, [week]: 0 };
			}
		});
		return walletRow;
	});

	const parser = new Parser({ fields });
	const csvContent = parser.parse(sortedWallets);
	fs.writeFileSync(`${network}-pool-${pool}-stakers.csv`, csvContent);
}

async function main() {
	// Processing Optimism Pool 1
	await fetchAndProcessStakers('optimism', 1);
	// Processing Optimism Pool 2
	// await fetchAndProcessStakers('optimism', 2);
	// Processing Ethereum Pool 2
	// await fetchAndProcessStakers('ethereum', 2);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
