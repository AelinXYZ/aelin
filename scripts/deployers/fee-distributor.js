const { ethers } = require('hardhat');

async function main() {
	const [deployer] = await ethers.getSigners();

	console.log('Deploying contracts with the account:', deployer.address);

	console.log('Account balance:', (await deployer.getBalance()).toString());

	const AelinFeeDistributorFactory = await ethers.getContractFactory('AelinFeeDistributor');
	const merkleRoot = '0xcd904018b77a3860dc7c38267f0fcc9f402c6623a2bf1d8468c0199b346bc6d3';

	const aelinFeeDistributor = await AelinFeeDistributorFactory.deploy(merkleRoot);
	console.log('AelinFeeDistributor address:', aelinFeeDistributor.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
