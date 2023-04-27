const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
const fs = require('fs');
const rawDistribution = require('./optimism-deal-token-distribution.json');
const distribution = require('./distribution.json');
const { parseEther } = require('@ethersproject/units');

function removeAfter18Decimals(value) {
	const regex = /^(-?\d+\.\d{1,18})/;
	const match = value.match(regex);
	return match ? match[1] : value;
}

const generateSourceData = () => {
	let distributionArray = [];
	rawDistribution.forEach((d, i) => {
		distributionArray.push([
			i,
			d.address,
			parseEther(removeAfter18Decimals(d.allocation)).toString(),
		]);
	});
	fs.writeFileSync('./distribution.json', JSON.stringify(distributionArray));
};

const buildTree = () => {
	const tree = StandardMerkleTree.of(distribution, ['uint256', 'address', 'uint256']);
	console.log('Merkle Root:', tree.root);
	fs.writeFileSync('./tree.json', JSON.stringify(tree.dump()));
	// Obtaining a proof
	for (const [i, v] of tree.entries()) {
		if (v[1] === '0x6e3aa85db95bba36276a37ed93b12b7ab0782afb') {
			// (3)
			const proof = tree.getProof(i);
			console.log('Index:');
			console.log('Value:', v);
			console.log('Proof:', proof);
		}
	}
};

// generateSourceData();
buildTree();
