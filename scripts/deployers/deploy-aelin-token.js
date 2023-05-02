const { ethers } = require('hardhat');

async function main() {
	const [deployer] = await ethers.getSigners();

	console.log('Deploying contracts with the account:', deployer.address);

	console.log('Account balance:', (await deployer.getBalance()).toString());

	// TODO fill out the correct dao address for each deployment
	// const daoMultisigL2 = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

	// NOTE this is kovan
	const daoMultisigL2 = '0xDB51F28Aa245498ca3068058e7e25B1e89Ca0BdA';

	const AelinToken = await ethers.getContractFactory('AelinToken');
	const aelinToken = await AelinToken.deploy(daoMultisigL2);

	console.log('AelinToken address:', aelinToken.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
