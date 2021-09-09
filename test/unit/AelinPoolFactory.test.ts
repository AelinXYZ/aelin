import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { solidity } from "ethereum-waffle";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";
import { AelinPoolFactory } from "../../typechain";

const { deployContract, deployMockContract } = waffle;

chai.use(solidity);

describe("AelinPoolFactory", function () {
  it("Should call the createPool method", async function () {
    const signers = await ethers.getSigners();
    const purchaseToken = await deployMockContract(
      signers[0],
      ERC20Artifact.abi
    );
    const aelinDealLogic = await deployMockContract(
      signers[0],
      AelinDealArtifact.abi
    );
    // NOTE that the test will fail if this is a mock contract due to the
    // minimal proxy and initialize pattern. Technically this sort of
    // makes this an integration test but I am leaving it since it adds value
    const aelinPoolLogic = await deployContract(signers[0], AelinPoolArtifact);
    await purchaseToken.mock.decimals.returns(6);
    const aelinPoolFactory = (await deployContract(
      signers[0],
      AelinPoolFactoryArtifact
    )) as AelinPoolFactory;

    const sponsor = signers[1];
    const name = "Test token";
    const symbol = "AMA";
    const purchaseTokenCap = 1000000;
    const duration = 29388523;
    const sponsorFee = 3000;
    const purchaseExpiry = 30 * 60 + 1; // 30min and 1sec

    const result = await aelinPoolFactory
      .connect(sponsor)
      .createPool(
        name,
        symbol,
        purchaseTokenCap,
        purchaseToken.address,
        duration,
        sponsorFee,
        purchaseExpiry,
        aelinPoolLogic.address,
        aelinDealLogic.address
      );

    expect(result.value).to.equal(0);

    const [log] = await aelinPoolFactory.queryFilter(
      aelinPoolFactory.filters.CreatePool()
    );

    expect(log.args.poolAddress).to.be.properAddress;
    expect(log.args.name).to.equal("aePool-" + name);
    expect(log.args.symbol).to.equal("aeP-" + symbol);
    expect(log.args.purchaseTokenCap).to.equal(purchaseTokenCap);
    expect(log.args.purchaseToken).to.equal(purchaseToken.address);
    expect(log.args.duration).to.equal(duration);
    expect(log.args.sponsorFee).to.equal(sponsorFee);
    expect(log.args.sponsor).to.equal(sponsor.address);
    expect(log.args.purchaseExpiry).to.equal(purchaseExpiry);
  });
});
