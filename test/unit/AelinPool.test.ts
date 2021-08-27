import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { MockContract, solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import { AelinPool } from "../../typechain";
import { BigNumber } from "ethers";

const { deployContract, deployMockContract } = waffle;

chai.use(solidity);

describe("AelinPool", function () {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let holder: SignerWithAddress;
  let nonsponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  let aelinPool: AelinPool;
  let purchaseToken: MockContract;
  const purchaseTokenDecimals = 6;

  before(async () => {
    [deployer, sponsor, holder, nonsponsor, user1] = await ethers.getSigners();
    purchaseToken = await deployMockContract(deployer, ERC20Artifact.abi);
    await purchaseToken.mock.decimals.returns(purchaseTokenDecimals);
  });

  beforeEach(async () => {
    aelinPool = (await deployContract(sponsor, AelinPoolArtifact)) as AelinPool;
  });

  const name = "TestName";
  const symbol = "TestSymbol";
  const purchaseTokenCap = 9000000000;
  const duration = 1;
  const sponsorFee = 10;
  const purchaseExpiry = 30 * 60 + 1; // 30min and 1sec
  const aelinPoolName = `aePool-${name}`;
  const aelinPoolSymbol = `aeP-${symbol}`;

  const successfullyInitializePool = () =>
    aelinPool.initialize(
      name,
      symbol,
      purchaseTokenCap,
      purchaseToken.address,
      duration,
      sponsorFee,
      sponsor.address,
      purchaseExpiry
    );

  describe("initialize", function () {
    it("should revert if duration is greater than 1 year", async function () {
      await expect(
        aelinPool.initialize(
          name,
          symbol,
          purchaseTokenCap,
          purchaseToken.address,
          365 * 24 * 60 * 60 + 1, // 1 second greater than 365 days
          sponsorFee,
          sponsor.address,
          purchaseExpiry
        )
      ).to.be.revertedWith("max 1 year duration");
    });

    it("should revert if purchase expiry is less than 30 min", async function () {
      await expect(
        aelinPool.initialize(
          name,
          symbol,
          purchaseTokenCap,
          purchaseToken.address,
          duration,
          sponsorFee,
          sponsor.address,
          30 * 60 - 1 // 1 second less than 30min
        )
      ).to.be.revertedWith("min 30 minutes purchase expiry");
    });

    it("should revert if sponsor fee is too high", async function () {
      await expect(
        aelinPool.initialize(
          name,
          symbol,
          purchaseTokenCap,
          purchaseToken.address,
          duration,
          98001,
          sponsor.address,
          purchaseExpiry
        )
      ).to.be.revertedWith("exceeds max sponsor fee");
    });

    it("should successfully initialize", async function () {
      const tx = await successfullyInitializePool();

      expect(await aelinPool.name()).to.equal(aelinPoolName);
      expect(await aelinPool.symbol()).to.equal(aelinPoolSymbol);
      expect(await aelinPool.PURCHASE_TOKEN_CAP()).to.equal(purchaseTokenCap);
      expect(await aelinPool.PURCHASE_TOKEN()).to.equal(purchaseToken.address);
      expect(await aelinPool.PURCHASE_TOKEN_DECIMALS()).to.equal(
        purchaseTokenDecimals
      );
      expect(await aelinPool.SPONSOR_FEE()).to.equal(sponsorFee);
      expect(await aelinPool.SPONSOR()).to.equal(sponsor.address);

      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);
      const expectedPoolExpiry = timestamp + duration;
      expect(await aelinPool.pool_expiry()).to.equal(expectedPoolExpiry);

      const expectedPurchaseExpiry = timestamp + purchaseExpiry;
      expect(await aelinPool.purchase_expiry()).to.equal(
        expectedPurchaseExpiry
      );
    });

    it("should only allow initialization once", async function () {
      await successfullyInitializePool();
      await expect(successfullyInitializePool()).to.be.revertedWith(
        "can only initialize once"
      );
    });
  });

  describe("createDeal", async function () {
    let underlyingToken: MockContract;

    before(async () => {
      underlyingToken = await deployMockContract(holder, ERC20Artifact.abi);
    });

    const dealPurchaseTokenTotal = 1000000;
    const underlyingDealTokenTotal = 1000000;
    const vestingPeriod = 1; // value doesn't matter for pool
    const vestingCliff = 1; // value doesn't matter for pool
    const redemptionPeriod = 30 * 60 + 1; // 1 second greater than minimum

    const createDealWithValidParams = () =>
      aelinPool.createDeal(
        underlyingToken.address,
        dealPurchaseTokenTotal,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        redemptionPeriod,
        holder.address
      );

    it("should revert if redemption period is too short", async function () {
      await successfullyInitializePool();
      await expect(
        aelinPool.createDeal(
          underlyingToken.address,
          dealPurchaseTokenTotal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          30 * 60 - 1, // 1 second less than minimum
          holder.address
        )
      ).to.be.revertedWith("30 mins is min redeem period");
    });

    it("should revert if the pool has no purchase tokens", async function () {
      await successfullyInitializePool();
      await purchaseToken.mock.balanceOf.withArgs(aelinPool.address).returns(0);
      await expect(createDealWithValidParams()).to.be.revertedWith(
        "no purchase tokens in the contract"
      );
    });

    it("should revert if the purchase total exceeds the pool balance", async function () {
      await successfullyInitializePool();
      await purchaseToken.mock.balanceOf
        .withArgs(aelinPool.address)
        .returns(dealPurchaseTokenTotal - 1);

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "not enough funds avail"
      );
    });

    it("should revert if the pool is not initialized", async function () {
      await expect(createDealWithValidParams()).to.be.revertedWith(
        "only sponsor can access"
      );
    });

    it("should revert if non-sponsor attempts to call it", async function () {
      await successfullyInitializePool();
      await expect(
        aelinPool
          .connect(nonsponsor)
          .createDeal(
            underlyingToken.address,
            dealPurchaseTokenTotal,
            underlyingDealTokenTotal,
            vestingPeriod,
            vestingCliff,
            redemptionPeriod,
            holder.address
          )
      ).to.be.revertedWith("only sponsor can access");
    });

    it("should successfully create a deal", async function () {
      // setup so that a user can purchase pool tokens
      const userPurchaseAmt = 100000;
      await purchaseToken.mock.balanceOf
        .withArgs(user1.address)
        .returns(userPurchaseAmt);

      await purchaseToken.mock.transferFrom
        .withArgs(user1.address, aelinPool.address, userPurchaseAmt)
        .returns(true);

      await purchaseToken.mock.balanceOf
        .withArgs(aelinPool.address)
        .returns(userPurchaseAmt);

      await successfullyInitializePool();
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);

      await purchaseToken.mock.balanceOf
        .withArgs(aelinPool.address)
        .returns(dealPurchaseTokenTotal + 1);

      const tx = await createDealWithValidParams();
      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);

      expect(await aelinPool.pool_expiry()).to.equal(timestamp);
      expect(await aelinPool.holder()).to.equal(holder.address);

      // TODO: confirm this
      expect(await aelinPool.PRO_RATA_CONVERSION()).to.equal(
        BigNumber.from("10000000000000000000")
      );

      const [log] = await aelinPool.queryFilter(aelinPool.filters.CreateDeal());

      expect(log.args.name).to.equal(aelinPoolName);
      expect(log.args.symbol).to.equal(aelinPoolSymbol);
      expect(log.args.dealContract).to.be.properAddress;
      expect(log.args.underlyingDealToken).to.equal(underlyingToken.address);
      expect(log.args.dealPurchaseTokenTotal).to.equal(dealPurchaseTokenTotal);
      expect(log.args.underlyingDealTokenTotal).to.equal(
        underlyingDealTokenTotal
      );
      expect(log.args.vestingPeriod).to.equal(vestingPeriod);
      expect(log.args.vestingCliff).to.equal(vestingCliff);
      expect(log.args.redemptionPeriod).to.equal(redemptionPeriod);
      expect(log.args.holder).to.equal(holder.address);
      expect(log.args.poolTokenMaxPurchaseAmount).to.equal(
        BigNumber.from(dealPurchaseTokenTotal).mul(
          10 ** (18 - purchaseTokenDecimals)
        )
      );

      // TODO: consider moving to own test
      await expect(createDealWithValidParams()).to.be.revertedWith(
        "deal has been created"
      );
    });
  });
});
