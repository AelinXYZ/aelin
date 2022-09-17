const fs = require('fs');
const { request, gql } = require('graphql-request');
const { getAddress } = require('@ethersproject/address');

async function main() {
	const endpoint = 'https://api.thegraph.com/subgraphs/name/aelin-xyz/aelin-optimism';

	const query = gql`
		query getAccepted($poolAddress: String!) {
			acceptDeals(first: 1000, where: { poolAddress: $poolAddress }) {
				purchaser
				poolTokenAmount
			}
		}
	`;

	const variables = {
		poolAddress: '0xe361Ac500fc1D91d49E2c0204963F2cadbcAF67a',
	};
	const TOTAL_sUSD = 1200000;
	const TOTAL_OP = 866963.2;

	const data = await request(endpoint, query, variables);
	console.log('data.acceptDeals.length', data.acceptDeals.length);

	let tempData = {};
	data.acceptDeals.map(({ purchaser, poolTokenAmount }) => {
		if (tempData[getAddress(purchaser)]) {
			tempData[getAddress(purchaser)] += Number(poolTokenAmount) / 1e18;
		} else {
			tempData[getAddress(purchaser)] = Number(poolTokenAmount) / 1e18;
		}
	});

	const readableOutput = Object.entries(tempData).reduce((acc, curr) => {
		acc[curr[0]] = (curr[1] / TOTAL_sUSD) * TOTAL_OP;
		return acc;
	}, {});

	const sortedOutput = Object.entries(readableOutput)
		.sort((a, b) => b[1] - a[1])
		.reduce(
			(_sortedObj, [k, v]) => ({
				..._sortedObj,
				[k]: v,
			}),
			{}
		);

	fs.writeFileSync(
		`./scripts/helpers/op-accepted.json`,
		JSON.stringify(sortedOutput),
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
