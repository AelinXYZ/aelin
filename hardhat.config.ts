import '@matterlabs/hardhat-zksync-deploy';
import '@matterlabs/hardhat-zksync-solc';
import '@matterlabs/hardhat-zksync-verify';

module.exports = {
	zksolc: {
		version: '1.3.10',
		compilerSource: 'binary',
		settings: {
			libraries: {
				'contracts/libraries/AelinAllowList.sol': {
					AelinAllowList: '0x9A55aF3701CCFe9192B367c514178652cAcaAFA1',
				},
				'contracts/libraries/AelinNftGating.sol': {
					AelinNftGating: '0xB4284b6819B6d16aF26E4DC91Bc7eb831C407794',
				},
				'contracts/libraries/MerkleTree.sol': {
					MerkleTree: '0x5B2Bf8155940d741a85f924154CD4Deb6693B61e',
				},
			},
		},
	},
	defaultNetwork: 'zkSyncTestnet',

	networks: {
		zkSyncTestnet: {
			url: 'https://testnet.era.zksync.dev',
			ethNetwork: 'goerli', // RPC URL of the network (e.g. `https://goerli.infura.io/v3/<API_KEY>`)
			zksync: true,
			verifyURL: 'https://zksync2-testnet-explorer.zksync.dev/contract_verification',
		},
	},
	// paths: {
	// 	sources: './contracts/libraries',
	// },
	solidity: {
		version: '0.8.6',
	},
};
