const stakingData = require('./staking-data.json');
const fs = require('fs');

let merkleObject = {};

stakingData.forEach(({address, vAELIN}) => {
	merkleObject[address] = Number(vAELIN) * 1e18;
})

fs.writeFileSync(
	`./merkle-data.json`,
	JSON.stringify(merkleObject),
	function (err) {
		if (err) return console.log(err);
	}
);


