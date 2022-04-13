const { ethers } = require('ethers');
const stakingData = require('./staking-data.json');
const _ = require('lodash');
const fs = require('fs');

const ARCHIVE_NODE_URL = '';
const ARCHIVE_NODE_USER = '';
const ARCHIVE_NODE_PASS = '';

const provider = new ethers.providers.JsonRpcProvider({
	url: ARCHIVE_NODE_URL,
	user: ARCHIVE_NODE_USER,
	password: ARCHIVE_NODE_PASS,
});

const runAllQueries = async (source) => {
	const batches = _.chunk(source, 50);
	const results = [];
	while (batches.length) {
		const batch = batches.shift();
		console.log('batching');
		const result = await Promise.all(batch.map(({ address }) => provider.getCode(address)));
		results.push(result);
	}
	return _.flatten(results);
};

const init = async () => {
	const results = await runAllQueries(stakingData);
	const contractWallets = results
		.map((code, i) => {
			return {
				address: stakingData[i].address,
				code: code,
				vAELIN: stakingData[i].vAELIN,
			};
		})
		.filter(({ code }) => code !== '0x')
		.map(({ address, vAELIN }) => ({ address, vAELIN }));
	console.log('Total wallet', results.length);
	console.log('Total contracts', contractWallets.length);

	console.log(contractWallets);

	fs.writeFileSync(`./contract-wallets.json`, JSON.stringify(contractWallets), function (err) {
		if (err) return console.log(err);
	});
};

init();
