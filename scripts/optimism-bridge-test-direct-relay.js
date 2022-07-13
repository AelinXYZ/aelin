const { ethers } = require('hardhat');
const OptimismTreasuryArtifact = require('../artifacts/contracts/OptimismTreasury.sol/OptimismTreasury.json');
const OwnerRelayOnOptimismArtifact = require('../artifacts/contracts/OwnerRelayOnOptimism.sol/OwnerRelayOnOptimism.json');

async function main() {
	const bridgeAddress = '0x88FdC711EFF5877B464D299C7ac3077135C6C5ca';

	const [deployer] = await ethers.getSigners();
	const ownerRelayOnOptimism = await ethers.getContractAt(
		OwnerRelayOnOptimismArtifact.abi,
		bridgeAddress
	);

	const optimismTreasuryAddress = '0x55c1688587e6DfD52E44BF8B7028a8f7525296E7';
	const optimismTreasury = await ethers.getContractAt(
		OptimismTreasuryArtifact.abi,
		optimismTreasuryAddress
	);
	const tokenToTransferAddress = '0xA7A86ec3C266435C580354d8c9A33b1BC91697A7';
	const transferTo = '0x24Fa2b48178f4aCD577230B3aC30b935195dCaf3';
	const transferAmount = '765306122448980000000';
	const transferPayload = optimismTreasury.interface.encodeFunctionData(
		'transferToken(address,address,uint256)',
		[tokenToTransferAddress, transferTo, transferAmount]
	);
	const tx = await ownerRelayOnOptimism
		.connect(deployer)
		.directRelay(optimismTreasuryAddress, transferPayload, {
			gasLimit: 8000000,
		});
	console.log('tx submitted', tx);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
