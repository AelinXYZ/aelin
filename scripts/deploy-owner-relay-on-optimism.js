const { ethers } = require('hardhat');

async function main() {
	const [deployer] = await ethers.getSigners();

	console.log('Deploying contracts with the account:', deployer.address);

	console.log('Account balance:', (await deployer.getBalance()).toString());

	const OwnerRelayOnOptimism = await ethers.getContractFactory('OwnerRelayOnOptimism');
	// NOTE deploy, test directRelay from the owner to make sure it is working
	// also call setContractData from the owner before the ownershipDuration is done
	const temporaryOwner = deployer.address;
	// one hour of ownership on the contract to test direct relay and set the contract data
	const ownershipDuration = 24 * 60 * 60; // 24 hours to start for testing
	const ownerRelayOnOptimism = await OwnerRelayOnOptimism.deploy(temporaryOwner, ownershipDuration);

	console.log('OwnerRelayOnOptimism address:', ownerRelayOnOptimism.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
