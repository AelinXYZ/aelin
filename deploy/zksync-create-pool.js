import { Contract } from '@ethersproject/contracts';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';

import AelinPoolFactoryABI from './AelinPoolFactory.json' assert { type: 'json' };
import AelinUpfrontDealFactoryABI from './AelinUpfrontDealFactory.json' assert { type: 'json' };

import dotenv from 'dotenv';
dotenv.config();

const POOL_FACTORY_ADDRESS = '0x16F6F1C7A70192eE74608acbC402540406EDe694';
// const UPFRONT_DEAL_FACTORY_ADDRESS = '0xB96b0F70bae68a9efdfA2F7bf89876401DD23E1D';

const provider = new JsonRpcProvider('https://testnet.era.zksync.dev');
const signer = new Wallet(process.env.ZKSYNC_PRIVATE_KEY, provider);
console.log(signer);

const contract = new Contract(POOL_FACTORY_ADDRESS, AelinPoolFactoryABI, signer);
// const contract = new Contract(UPFRONT_DEAL_FACTORY_ADDRESS, AelinUpfrontDealFactoryABI, signer);

const poolLogic = await contract.AELIN_POOL_LOGIC();
// const poolLogic = await contract.UP_FRONT_DEAL_LOGIC();
console.log('AELIN_POOL_LOGIC: ', poolLogic);

const createPoolEstimate = await contract.createPool(
	{
		name: 'TST',
		symbol: 'TST',
		purchaseTokenCap: 0,
		purchaseToken: '0x0BfcE1D53451B4a8175DD94e6e029F7d8a701e9c',
		duration: 3600,
		sponsorFee: 0,
		purchaseDuration: 3600,
		allowListAddresses: [],
		allowListAmounts: [],
		nftCollectionRules: [],
	},
	{ gasLimit: 1000000 }
);

try {
	const tx = await createPoolEstimate.wait();
	console.log(tx);
} catch (e) {
	console.log('err', e);
}

// const createPoolEstimate = await contract.estimateGas.createUpFrontDeal(
// 	{
// 		name: 'DEAL',
// 		symbol: 'DEAL',
// 		purchaseToken: '0x0BfcE1D53451B4a8175DD94e6e029F7d8a701e9c',
// 		underlyingDealToken: '0x3e7676937A7E96CFB7616f255b9AD9FF47363D4b',
// 		holder: '0x3787D321e3eCe1E4ca7D7449D49A4Fb5F85dc447',
// 		sponsor: '0x0100352F74A80bBED73F4941aBc57eC6B8a43a32',
// 		sponsorFee: 0,
// 		merkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000',
// 		ipfsHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
// 	},
// 	{
// 		underlyingDealTokenTotal: 0,
// 		purchaseTokenPerDealToken: 0,
// 		purchaseRaiseMinimum: 0,
// 		purchaseDuration: 86400,
// 		vestingPeriod: 0,
// 		vestingCliffPeriod: 0,
// 		allowDeallocation: true,
// 	},
// 	[],
// 	{
// 		allowListAddresses: [],
// 		allowListAmounts: [],
// 	}
// );

console.log(createPoolEstimate);
