import { Wallet } from 'zksync-web3';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

import dotenv from 'dotenv';
dotenv.config();

const PRIVATE_KEY = process.env.ZKSYNC_PRIVATE_KEY || '';

if (!PRIVATE_KEY) throw '⛔️ Private key not detected! Add it to the .env file!';

export default async function (hre: HardhatRuntimeEnvironment) {
	console.log(`Running deploy script for the library contracts`);

	const wallet = new Wallet(PRIVATE_KEY);

	const deployer = new Deployer(hre, wallet);

	const aelinAllowList = await deployer.loadArtifact('AelinAllowList');
	const aelinNftGating = await deployer.loadArtifact('AelinNftGating');
	const merkleTree = await deployer.loadArtifact('MerkleTree');

	console.log('=============== deployment ================');

	console.log('Deploying AllowList contract...');
	const allowListContract = await deployer.deploy(aelinAllowList);
	console.log('Address: ', allowListContract.address);

	console.log('Deploying NftGating contract...');
	const nftGatingContract = await deployer.deploy(aelinNftGating);
	console.log('Address: ', nftGatingContract.address);

	console.log('Deploying MerkleTree contract...');
	const merkleTreeContract = await deployer.deploy(merkleTree);
	console.log('Address: ', merkleTreeContract.address);

	console.log('============ verification ================');

	let verificationId = await hre.run('verify:verify', {
		address: allowListContract.address,
		contract: 'contracts/libraries/AelinAllowList.sol:AelinAllowList',
		constructorArguments: [],
	});
	console.log('Verification ID for AllowList: ', verificationId);

	verificationId = await hre.run('verify:verify', {
		address: nftGatingContract.address,
		contract: 'contracts/libraries/AelinNftGating.sol:AelinNftGating',
		constructorArguments: [],
	});
	console.log('Verification ID for AelinNftGating: ', verificationId);

	verificationId = await hre.run('verify:verify', {
		address: merkleTreeContract.address,
		contract: 'contracts/libraries/MerkleTree.sol:MerkleTree',
		constructorArguments: [],
	});
	console.log('Verification ID for MerkleTree: ', verificationId);

	console.log('============ addresses ================');

	console.log('AelinAllowList: ', allowListContract.address);
	console.log('AelinNftGating: ', nftGatingContract.address);
	console.log('MerkleTree: ', merkleTreeContract.address);
}
