const fs = require('fs');
const { request, gql } = require('graphql-request');
const { ethers } = require('ethers');
const { getAddress } = require('@ethersproject/address');

async function main() {
	const optimismBatchTransaction = {
		version: '1.0',
		chainId: '10',
		createdAt: 1663452378091,
		meta: {
			name: 'Transactions Batch',
			description: '',
			txBuilderVersion: '1.10.0',
			createdFromSafeAddress: '0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f',
			createdFromOwnerAddress: '',
			checksum: '0xac6e6cff0490ed6f300b54afbe44e357a7b17a28e2d38966608fd0c2058cfcc2',
		},
		transactions: [],
	};
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
		optimismBatchTransaction.transactions.push({
			to: '0x4200000000000000000000000000000000000042',
			value: '0',
			data: null,
			contractMethod: {
				inputs: [
					{ internalType: 'address', name: 'to', type: 'address' },
					{ internalType: 'uint256', name: 'amount', type: 'uint256' },
				],
				name: 'transfer',
				payable: false,
			},
			contractInputsValues: {
				to: curr[0],
				amount: opAmount.toString(),
			},
		});
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

	fs.writeFileSync(
		`./scripts/helpers/OPTransactionsBatch.json`,
		JSON.stringify(optimismBatchTransaction),
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
