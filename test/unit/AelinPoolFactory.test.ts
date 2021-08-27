import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { solidity } from "ethereum-waffle";

import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";
import { AelinPoolFactory } from "../../typechain";

const { deployContract } = waffle;

chai.use(solidity);

describe("AelinPoolFactory", function () {
  it("Should call the createPool method", async function () {
    const signers = await ethers.getSigners();
    const aelinPoolFactory = (await deployContract(
      signers[0],
      AelinPoolFactoryArtifact
    )) as AelinPoolFactory;

    const sponsor = signers[1];
    const name = "Test token";
    const symbol = "AMA";
    const purchaseTokenCap = 100;
    const purchaseTokenAddress = "0x99C85bb64564D9eF9A99621301f22C9993Cb89E3";
    const duration = 29388523;
    const sponsorFee = 3000;
    const purchaseExpiry = 9388523;

    const result = await aelinPoolFactory
      .connect(sponsor)
      .createPool(
        name,
        symbol,
        purchaseTokenCap,
        purchaseTokenAddress,
        duration,
        sponsorFee,
        purchaseExpiry
      );

    expect(result.value).to.equal(0);

    const [log] = await aelinPoolFactory.queryFilter(
      aelinPoolFactory.filters.CreatePool()
    );

    expect(log.args.poolAddress).to.be.properAddress;
    expect(log.args.name).to.equal(name);
    expect(log.args.symbol).to.equal(symbol);
    expect(log.args.purchaseTokenCap).to.equal(purchaseTokenCap);
    expect(log.args.purchaseToken).to.equal(purchaseTokenAddress);
    expect(log.args.duration).to.equal(duration);
    expect(log.args.sponsorFee).to.equal(sponsorFee);
    expect(log.args.sponsor).to.equal(sponsor.address);
    expect(log.args.purchaseExpiry).to.equal(purchaseExpiry);
  });
});
