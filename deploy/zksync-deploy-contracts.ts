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

	const feeEscrow = await deployer.loadArtifact('AelinFeeEscrow');
	const deal = await deployer.loadArtifact('AelinDeal');
	const pool = await deployer.loadArtifact('AelinPool');
	const upFrontDeal = await deployer.loadArtifact('AelinUpFrontDeal');

	const poolFactory = await deployer.loadArtifact('AelinPoolFactory');
	const upFrontDealFactory = await deployer.loadArtifact('AelinUpFrontDealFactory');

	// Deployment
	console.log('Deploying AelinFeeEscrow contract...');
	const feeEscrowContract = await deployer.deploy(feeEscrow);

	console.log('Deploying AelinDeal contract...');
	const dealContract = await deployer.deploy(deal);

	console.log('Deploying AelinPool contract...');
	const poolContract = await deployer.deploy(pool);

	console.log('Deploying AelinUpFrontDeal contract...');
	const upFrontDealContract = await deployer.deploy(upFrontDeal);

	console.log('Deploying AelinPoolFactory contract...');
	const poolFactoryContract = await deployer.deploy(poolFactory, [
		poolContract.address,
		dealContract.address,
		wallet.address,
		feeEscrowContract.address,
	]);

	console.log('Deploying AelinUpFrontDealFactory contract...');
	const upFrontDealFactoryContract = await deployer.deploy(upFrontDealFactory, [
		upFrontDealContract.address,
		feeEscrowContract.address,
		wallet.address,
	]);

	// Logs
	console.log(
		'AelinPoolFactory constructor args:' +
			poolFactoryContract.interface.encodeDeploy([
				poolContract.address,
				dealContract.address,
				wallet.address,
				feeEscrowContract.address,
			])
	);

	console.log(
		'AelinUpFrontDealFactory constructor args:' +
			upFrontDealFactoryContract.interface.encodeDeploy([
				upFrontDealContract.address,
				feeEscrowContract.address,
				wallet.address,
			])
	);

	console.log('Verification for AelinFeeEscrow...');
	let verificationId = await hre.run('verify:verify', {
		address: feeEscrowContract.address,
		contract: 'contracts/AelinFeeEscrow.sol:AelinFeeEscrow',
		constructorArguments: [],
	});
	console.log('Verification ID for AelinFeeEscrow: ', verificationId);

	console.log('Verification for AelinDeal...');
	verificationId = await hre.run('verify:verify', {
		address: dealContract.address,
		contract: 'contracts/AelinDeal.sol:AelinDeal',
		constructorArguments: [],
	});
	console.log('Verification ID for AelinDeal: ', verificationId);

	console.log('Verification for AelinPool...');
	verificationId = await hre.run('verify:verify', {
		address: poolContract.address,
		contract: 'contracts/AelinPool.sol:AelinPool',
		constructorArguments: [],
	});
	console.log('Verification ID for AelinPool: ', verificationId);

	console.log('Verification for AelinUpFrontDeal...');
	verificationId = await hre.run('verify:verify', {
		address: upFrontDealContract.address,
		contract: 'contracts/AelinUpFrontDeal.sol:AelinUpFrontDeal',
		constructorArguments: [],
	});
	console.log('Verification ID for AelinUpFrontDeal: ', verificationId);

	console.log('Verification for AelinPoolFactory...');
	verificationId = await hre.run('verify:verify', {
		address: poolFactoryContract.address,
		contract: 'contracts/AelinPoolFactory.sol:AelinPoolFactory',
		constructorArguments: [
			poolContract.address,
			dealContract.address,
			wallet.address,
			feeEscrowContract.address,
		],
	});
	console.log('Verification ID for AelinPoolFactory: ', verificationId);

	console.log('Verification for AelinUpFrontDealFactory...');
	verificationId = await hre.run('verify:verify', {
		address: upFrontDealFactoryContract.address,
		contract: 'contracts/AelinUpFrontDealFactory.sol:AelinUpFrontDealFactory',
		constructorArguments: [upFrontDealContract.address, feeEscrowContract.address, wallet.address],
	});
	console.log('Verification ID for AelinUpFrontDealFactory: ', verificationId);

	console.log('AelinFeeEscrow address: ', feeEscrowContract.address);
	console.log('AelinDeal address: ', dealContract.address);
	console.log('AelinPool address: ', poolContract.address);
	console.log('AelinUpFrontDeal address: ', upFrontDealContract.address);
	console.log('AelinPoolFactory address: ', poolFactoryContract.address);
	console.log('AelinUpFrontDealFactory address: ', upFrontDealFactoryContract.address);
}
