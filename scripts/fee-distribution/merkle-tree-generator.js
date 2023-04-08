const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
const fs = require('fs');

// Building the tree
const values = [
	[0, '0x1111111111111111111111111111111111111111', '500000000000000000'],
	[1, '0x2222222222222222222222222222222222222222', '250000000000000000'],
	[2, '0x3333333333333333333333333333333333333333', '250000000000000000'],
];

const tree = StandardMerkleTree.of(values, ['uint256', 'address', 'uint256']);
console.log('Merkle Root:', tree.root);
fs.writeFileSync('./tree.json', JSON.stringify(tree.dump()));

// Obtaining a proof
for (const [i, v] of tree.entries()) {
	if (v[1] === '0x3333333333333333333333333333333333333333') {
		// (3)
		const proof = tree.getProof(i);
		console.log('Index:');
		console.log('Value:', v);
		console.log('Proof:', proof);
	}
}
