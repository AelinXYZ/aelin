const { ethers } = require('hardhat');

// NOTE that we want to hardcode the Deal and Pool logic addresses
// in the AelinPoolFactory before deployment
async function main() {
	const [deployer] = await ethers.getSigners();

	console.log('Deploying contracts with the account:', deployer.address);

	console.log('Account balance:', (await deployer.getBalance()).toString());

	// TODO fill out the correct fields for each deployment - these are mainnet values
	// const poolLogicAddress = "0x80aFb16eB991BC0a5Bfc0515A562dAD362084C4b";
	// const dealLogicAddress = "0x2569f66b7Acd8954A7B3A48481823e30c4990742";
	// const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

	// mainnet v2
	// const poolLogicAddress = "0x4465A2a34684D5fDe76EfD1597553F6D81617412";
	// const dealLogicAddress = "0x1fa677ca369b97Ab30707373531cB050b1c3a7c6";
	// const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

	// mainnet v3
	// const poolLogicAddress = "0x15867Ce46c192F3AA5840f7F7f54C1752f2A9762";
	// const dealLogicAddress = "0xeF1C0B40016d0EA08e4F409f48e618B41eDF66D9";
	// const rewardsAddress = "0x51b0332E1b3349bcF01689E63e34d8859595e376";

	// mainnet OP deployed contracts
	// const poolLogicAddress = "0x689b7D709106bc488f872C50B688F058048536BE";
	// const dealLogicAddress = "0xBca527108Bcc3DE437C5Bfdb1A5489DE26DeEaE0";
	// const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

	// mainnet OP deployed contracts v2
	// const poolLogicAddress = "0x528D21fd31b0764BefBF5b584f962e3cE7Dda296";
	// const dealLogicAddress = "0x3c8BEf5F8Df313ea6cb874d5035d3eeb963d8dAd";
	// const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

	// mainnet OP deployed contracts v3
	// const poolLogicAddress = "0x29e146346242e3D206DD36a79E274c753BFFb15E";
	// const dealLogicAddress = "0x722969A3fdc778a5cC7CbC8DC8Ae3e96a288f853";
	// const rewardsAddress = "0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f";

	// mainnet OP deployed contracts v4
	const poolLogicAddress = '0x9d30dE9EeEb855D08c22155593FA5e035a742108';
	const dealLogicAddress = '0x2b58528dABF7fC3Ed0102DF7bfE2578e951bDE02';
	const rewardsAddress = '0x5B8F3fb479571Eca6A06240b21926Db586Cdf10f';
	const escrowAddress = '0xf145650Cbb189f5f05ece057fc55F341d513C8C4';
	// goerli deployed contracts
	// const poolLogicAddress = "0xE46d449924A74D3155B2605E12399D22401f16E4";
	// const dealLogicAddress = "0xBE68F3E4B5CEbaAB155582a4220cDf8E439861A5";
	// const rewardsAddress = "0x9d6DC72ED8ff3464cFd814c9Bb1Db0aFB157Cb97";

	// kovan deployed contracts
	// const poolLogicAddress = '0x0ad6487267c5F92e588F1e72d60FC39d54cBE8EF';
	// const dealLogicAddress = '0xB32F6CfC7Db506be9D3F45EC5d008165A26DE098';
	// const rewardsAddress = '0x7856f2a12A7A18b4A115d295F548434a9b078fA1';

	const AelinPoolFactory = await ethers.getContractFactory('AelinPoolFactory');
	const aelinPoolFactory = await AelinPoolFactory.deploy(
		poolLogicAddress,
		dealLogicAddress,
		rewardsAddress,
		escrowAddress
	);

	console.log('AelinPoolFactory address:', aelinPoolFactory.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
