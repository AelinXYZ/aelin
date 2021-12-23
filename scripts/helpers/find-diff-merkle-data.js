const merkleData = require("./merkle-data.json");
let vAELINTotal = 0;

Object.entries(merkleData).forEach(([address, vAELIN]) => {
  vAELINTotal += Number(vAELIN);
});

console.log(765306122448979591836 - vAELINTotal);
