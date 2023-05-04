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

	console.log('Deploying AllowList contract...');
	const allowListContract = await deployer.deploy(aelinAllowList);
	console.log('Address: ', allowListContract.address);

	console.log('Deploying NftGating contract...');
	const nftGatingContract = await deployer.deploy(aelinNftGating);
	console.log('Address: ', nftGatingContract.address);

	console.log('Deploying AllowList contract...');
	const merkleTreeContract = await deployer.deploy(merkleTree);
	console.log('Address: ', merkleTreeContract.address);
}
