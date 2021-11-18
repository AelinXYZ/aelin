import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { MockContract, solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";
import { AelinPool, AelinPoolFactory } from "../../typechain";
import { mockAelinRewardsAddress, nullAddress } from "../helpers";

const { deployContract, deployMockContract } = waffle;

chai.use(solidity);

describe("AelinPoolFactory", function () {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let purchaseToken: MockContract;
  let aelinDealLogic: MockContract;
  let aelinPoolLogic: AelinPool;
  let aelinPoolFactory: AelinPoolFactory;

  const name = "Test token";
  const symbol = "AMA";
  const purchaseTokenCap = 1000000;
  const duration = 29388523;
  const sponsorFee = 3000;
  const purchaseExpiry = 30 * 60 + 1; // 30min and 1sec

  before(async () => {
    const signers = await ethers.getSigners();
    [deployer, sponsor] = signers;
    purchaseToken = await deployMockContract(deployer, ERC20Artifact.abi);
    aelinDealLogic = await deployMockContract(deployer, AelinDealArtifact.abi);
    // NOTE that the test will fail if this is a mock contract due to the
    // minimal proxy and initialize pattern. Technically this sort of
    // makes this an integration test but I am leaving it since it adds value
    aelinPoolLogic = (await deployContract(
      deployer,
      AelinPoolArtifact
    )) as AelinPool;
    await purchaseToken.mock.decimals.returns(6);
    aelinPoolFactory = (await deployContract(
      deployer,
      AelinPoolFactoryArtifact,
      [aelinPoolLogic.address, aelinDealLogic.address, mockAelinRewardsAddress]
    )) as AelinPoolFactory;
  });

  it("Should call the createPool method", async function () {
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
        [],
        []
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
    expect(log.args.purchaseDuration).to.equal(purchaseExpiry);
  });

  it("Should revert when purchse token is zero address", async function () {
    await expect(
      aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseTokenCap,
          nullAddress,
          duration,
          sponsorFee,
          purchaseExpiry
        )
    ).to.be.revertedWith("cant pass null token address");
  });

  it("Should revert when any constructor value is a zero address", async function () {
    await expect(
      deployContract(deployer, AelinPoolFactoryArtifact, [
        nullAddress,
        aelinDealLogic.address,
        mockAelinRewardsAddress,
      ])
    ).to.be.revertedWith("cant pass null pool address");

    await expect(
      deployContract(deployer, AelinPoolFactoryArtifact, [
        aelinPoolLogic.address,
        nullAddress,
        mockAelinRewardsAddress,
      ])
    ).to.be.revertedWith("cant pass null deal address");

    await expect(
      deployContract(deployer, AelinPoolFactoryArtifact, [
        aelinPoolLogic.address,
        aelinDealLogic.address,
        nullAddress,
      ])
    ).to.be.revertedWith("cant pass null rewards address");
  });
});
