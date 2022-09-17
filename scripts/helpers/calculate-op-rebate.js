const fs = require('fs');
const { request, gql } = require('graphql-request');
const { ethers } = require('ethers');
const { getAddress } = require('@ethersproject/address');

async function main() {
	const decimals = 18;
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
	const TOTAL_sUSD = ethers.utils.parseUnits('1200000', decimals);
	const TOTAL_OP = ethers.utils.parseUnits('866963.20000000000007', decimals);

	const data = await request(endpoint, query, variables);
	console.log('data.acceptDeals.length', data.acceptDeals.length);

	let tempData = {};
	data.acceptDeals.map(({ purchaser, poolTokenAmount }) => {
		const value = ethers.utils.formatUnits(poolTokenAmount, decimals).toString();
		if (tempData[getAddress(purchaser)]) {
			tempData[getAddress(purchaser)] = String(
				Number(value) + Number(tempData[getAddress(purchaser)])
			);
		} else {
			tempData[getAddress(purchaser)] = value;
		}
	});

	const readableOutput = Object.entries(tempData).reduce((acc, curr) => {
		const opAmount = ethers.BigNumber.from(ethers.utils.parseUnits(curr[1], decimals))
			.mul(TOTAL_OP)
			.div(TOTAL_sUSD);
		acc[curr[0]] = opAmount.toString();
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
