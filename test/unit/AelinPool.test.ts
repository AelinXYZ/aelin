import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { MockContract, solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import { AelinPool, AelinDeal, ERC20 } from "../../typechain";
import { fundUsers, getImpersonatedSigner } from "../helpers";

const { deployContract, deployMockContract } = waffle;

chai.use(solidity);

describe("AelinPool", function () {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let holder: SignerWithAddress;
  let nonsponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  // NOTE that the test will fail if this is a mock contract due to the
  // minimal proxy and initialize pattern. Technically this sort of
  // makes this an integration test but I am leaving it since it adds value
  let aelinDealLogic: AelinDeal;
  let aelinPool: AelinPool;
  let purchaseToken: ERC20;
  let underlyingDealToken: MockContract;
  const purchaseTokenDecimals = 6;
  const underlyingDealTokenDecimals = 8;
  const poolTokenDecimals = 18;
  const mockAelinRewardsAddress = "0xfdbdb06109CD25c7F485221774f5f96148F1e235";
  const purchaseTokenAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  const purchaseTokenWhaleAddress =
    "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let purchaseTokenWhaleSigner: SignerWithAddress;

  const userPurchaseBaseAmt = 400;
  const userPurchaseAmt = ethers.utils.parseUnits(
    userPurchaseBaseAmt.toString(),
    purchaseTokenDecimals
  );

  const poolTokenAmount = userPurchaseAmt.mul(
    Math.pow(10, poolTokenDecimals - purchaseTokenDecimals)
  );
  const purchaseTokenTotalForDealBase = 100;
  const purchaseTokenTotalForDeal = ethers.utils.parseUnits(
    purchaseTokenTotalForDealBase.toString(),
    purchaseTokenDecimals
  );

  const purchaseTokenCapBase = 900;
  const purchaseTokenCap = ethers.utils.parseUnits(
    purchaseTokenCapBase.toString(),
    purchaseTokenDecimals
  );

  before(async () => {
    [deployer, sponsor, holder, nonsponsor, user1] = await ethers.getSigners();
    purchaseToken = (await ethers.getContractAt(
      ERC20Artifact.abi,
      purchaseTokenAddress
    )) as ERC20;
    aelinDealLogic = (await deployContract(
      deployer,
      AelinDealArtifact
    )) as AelinDeal;

    purchaseTokenWhaleSigner = await getImpersonatedSigner(
      purchaseTokenWhaleAddress
    );
    await fundUsers(
      purchaseToken,
      purchaseTokenWhaleSigner,
      purchaseTokenCap.mul(2),
      [user1]
    );
    underlyingDealToken = await deployMockContract(holder, ERC20Artifact.abi);
    await underlyingDealToken.mock.decimals.returns(
      underlyingDealTokenDecimals
    );
  });

  beforeEach(async () => {
    aelinPool = (await deployContract(sponsor, AelinPoolArtifact)) as AelinPool;
  });

  const name = "TestName";
  const symbol = "TestSymbol";

  const duration = 100;
  const sponsorFee = 1000;
  const purchaseExpiry = 30 * 60 + 1; // 30min and 1sec
  const aelinPoolName = `aePool-${name}`;
  const aelinPoolSymbol = `aeP-${symbol}`;

  const successfullyInitializePool = async () => {
    await purchaseToken
      .connect(user1)
      .approve(aelinPool.address, userPurchaseAmt);

    return aelinPool.initialize(
      name,
      symbol,
      purchaseTokenCap,
      purchaseToken.address,
      duration,
      sponsorFee,
      sponsor.address,
      purchaseExpiry,
      aelinDealLogic.address,
      mockAelinRewardsAddress
    );
  };

  const underlyingDealTokenTotalBase = 1000;
  const underlyingDealTokenTotal = ethers.utils.parseUnits(
    underlyingDealTokenTotalBase.toString(),
    underlyingDealTokenDecimals
  );

  const vestingPeriod = 1; // value doesn't matter for pool
  const vestingCliff = 1; // value doesn't matter for pool
  const proRataRedemptionPeriod = 30 * 60 + 1; // 1 second greater than minimum
  const openRedemptionPeriod = 30 * 60 + 1; // 1 second greater than minimum

  const createDealWithValidParams = () =>
    aelinPool
      .connect(sponsor)
      .createDeal(
        underlyingDealToken.address,
        purchaseTokenTotalForDeal,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        proRataRedemptionPeriod,
        openRedemptionPeriod,
        holder.address
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
          purchaseExpiry,
          aelinDealLogic.address,
          mockAelinRewardsAddress
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
          30 * 60 - 1, // 1 second less than 30min,
          aelinDealLogic.address,
          mockAelinRewardsAddress
        )
      ).to.be.revertedWith("outside purchase expiry window");
    });

    it("should revert if purchase expiry greater than 30 days", async function () {
      await expect(
        aelinPool.initialize(
          name,
          symbol,
          purchaseTokenCap,
          purchaseToken.address,
          duration,
          sponsorFee,
          sponsor.address,
          30 * 24 * 60 * 60 + 1, // 1 second more than 30 days
          aelinDealLogic.address,
          mockAelinRewardsAddress
        )
      ).to.be.revertedWith("outside purchase expiry window");
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
          purchaseExpiry,
          aelinDealLogic.address,
          mockAelinRewardsAddress
        )
      ).to.be.revertedWith("exceeds max sponsor fee");
    });

    it("should successfully initialize", async function () {
      const tx = await successfullyInitializePool();

      expect(await aelinPool.name()).to.equal(aelinPoolName);
      expect(await aelinPool.symbol()).to.equal(aelinPoolSymbol);
      expect(await aelinPool.purchaseTokenCap()).to.equal(purchaseTokenCap);
      const returnAddress = await aelinPool.purchaseToken();
      expect(returnAddress.toLowerCase()).to.equal(
        purchaseToken.address.toLowerCase()
      );
      expect(await aelinPool.purchaseTokenDecimals()).to.equal(
        purchaseTokenDecimals
      );
      expect(await aelinPool.sponsorFee()).to.equal(sponsorFee);
      expect(await aelinPool.sponsor()).to.equal(sponsor.address);

      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);
      const expectedPoolExpiry = timestamp + duration;
      expect(await aelinPool.poolExpiry()).to.equal(expectedPoolExpiry);

      const expectedPurchaseExpiry = timestamp + purchaseExpiry;
      expect(await aelinPool.purchaseExpiry()).to.equal(expectedPurchaseExpiry);

      const [log] = await aelinPool.queryFilter(aelinPool.filters.SetSponsor());
      expect(log.args.sponsor).to.equal(sponsor.address);
    });

    it("should only allow initialization once", async function () {
      await successfullyInitializePool();
      await expect(successfullyInitializePool()).to.be.revertedWith(
        "can only initialize once"
      );
    });
  });

  describe("createDeal", async function () {
    it("should revert if pool is still in purchase mode", async function () {
      await successfullyInitializePool();
      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address
        )
      ).to.be.revertedWith("pool still in purchase mode");
    });

    it("should revert if redemption period is too short", async function () {
      await successfullyInitializePool();
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod - 2, // 1 second less than minimum
          openRedemptionPeriod,
          holder.address
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");
    });

    it("should revert if redemption period is too long", async function () {
      await successfullyInitializePool();
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          30 * 24 * 60 * 60 + 1, // 1 second more than 30 days
          openRedemptionPeriod,
          holder.address
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");
    });

    it("should revert if the pool has no purchase tokens", async function () {
      await successfullyInitializePool();
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "not enough funds available"
      );
    });

    it("should revert if the purchase total exceeds the pool balance", async function () {
      await successfullyInitializePool();
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "not enough funds available"
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
            underlyingDealToken.address,
            purchaseTokenTotalForDeal,
            underlyingDealTokenTotal,
            vestingPeriod,
            vestingCliff,
            proRataRedemptionPeriod,
            openRedemptionPeriod,
            holder.address
          )
      ).to.be.revertedWith("only sponsor can access");
    });

    it("should fail when the open redemption period is too short or too long", async function () {
      // setup so that a user can purchase pool tokens
      await successfullyInitializePool();
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.connect(sponsor).createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod - 2, // 1 second less than minimum
          holder.address
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");

      await expect(
        aelinPool.connect(sponsor).createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          365 * 60 * 60 * 60, // more than 30 days
          holder.address
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");
    });

    it("should fail when the open redemption period is set when the totalSupply equals the deal purchase amount", async function () {
      await successfullyInitializePool();
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool
          .connect(sponsor)
          .createDeal(
            underlyingDealToken.address,
            userPurchaseAmt,
            underlyingDealTokenTotal,
            vestingPeriod,
            vestingCliff,
            proRataRedemptionPeriod,
            openRedemptionPeriod,
            holder.address
          )
      ).to.be.revertedWith("deal is 1:1, set open to 0");
    });

    it("should successfully create a deal", async function () {
      await successfullyInitializePool();
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      const tx = await createDealWithValidParams();
      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);

      expect(await aelinPool.poolExpiry()).to.equal(timestamp);
      expect(await aelinPool.holder()).to.equal(holder.address);

      const expectedProRataResult = (
        (purchaseTokenTotalForDealBase / userPurchaseBaseAmt) *
        10 ** 18
      ).toString();

      expect(await aelinPool.proRataConversion()).to.equal(
        expectedProRataResult
      );

      const [createDealLog] = await aelinPool.queryFilter(
        aelinPool.filters.CreateDeal()
      );
      const [dealDetailsLog] = await aelinPool.queryFilter(
        aelinPool.filters.DealDetails()
      );

      expect(createDealLog.args.name).to.equal(
        aelinPoolName.replace("Pool", "Deal")
      );
      expect(createDealLog.args.symbol).to.equal(
        aelinPoolSymbol.replace("P-", "D-")
      );
      expect(createDealLog.args.dealContract).to.be.properAddress;
      expect(createDealLog.args.sponsor).to.equal(sponsor.address);
      expect(createDealLog.args.poolAddress).to.equal(aelinPool.address);

      expect(dealDetailsLog.args.dealContract).to.be.properAddress;
      expect(dealDetailsLog.args.underlyingDealToken).to.equal(
        underlyingDealToken.address
      );
      expect(dealDetailsLog.args.purchaseTokenTotalForDeal).to.equal(
        purchaseTokenTotalForDeal
      );
      expect(dealDetailsLog.args.underlyingDealTokenTotal).to.equal(
        underlyingDealTokenTotal
      );
      expect(dealDetailsLog.args.vestingPeriod).to.equal(vestingPeriod);
      expect(dealDetailsLog.args.vestingCliff).to.equal(vestingCliff);
      expect(dealDetailsLog.args.proRataRedemptionPeriod).to.equal(
        proRataRedemptionPeriod
      );
      expect(dealDetailsLog.args.openRedemptionPeriod).to.equal(
        openRedemptionPeriod
      );
      expect(dealDetailsLog.args.holder).to.equal(holder.address);

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "deal has been created"
      );
    });
  });

  describe("changing the sponsor", function () {
    beforeEach(async function () {
      await successfullyInitializePool();
    });
    it("should fail to let a non sponsor change the sponsor", async function () {
      await expect(
        aelinPool.connect(user1).setSponsor(user1.address)
      ).to.be.revertedWith("only sponsor can access");
    });
    it("should change the sponsor only after the new sponsor is accepted", async function () {
      await aelinPool.connect(sponsor).setSponsor(user1.address);
      expect(await aelinPool.sponsor()).to.equal(sponsor.address);

      await expect(
        aelinPool.connect(sponsor).acceptSponsor()
      ).to.be.revertedWith("only future sponsor can access");
      await aelinPool.connect(user1).acceptSponsor();

      expect(await aelinPool.sponsor()).to.equal(user1.address);
      const [log, log2] = await aelinPool.queryFilter(
        aelinPool.filters.SetSponsor()
      );
      expect(log.args.sponsor).to.equal(sponsor.address);
      expect(log2.args.sponsor).to.equal(user1.address);
    });
  });

  describe("purchase pool tokens", function () {
    beforeEach(async function () {
      await successfullyInitializePool();
    });

    it("should successfully purchase pool tokens for the user", async function () {
      const maxPoolPurchase = await aelinPool.maxPoolPurchase();
      expect(maxPoolPurchase).to.equal(purchaseTokenCap);
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      const [log] = await aelinPool.queryFilter(
        aelinPool.filters.PurchasePoolToken()
      );

      expect(log.args.purchaser).to.equal(user1.address);
      expect(log.args.poolAddress).to.equal(aelinPool.address);
      expect(log.args.purchaseTokenAmount).to.equal(userPurchaseAmt);
      expect(log.args.poolTokenAmount).to.equal(poolTokenAmount);
    });

    it("should fail the transaction when the cap has been exceeded", async function () {
      const maxPoolPurchase = await aelinPool.maxPoolPurchase();
      // we are mocking the contract has the user balance already
      // but since we do the check on the pool token allocation
      // the user can purchase up to the cap
      expect(maxPoolPurchase).to.equal(purchaseTokenCap);
      await purchaseToken
        .connect(user1)
        .approve(aelinPool.address, purchaseTokenCap.add(1));
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(purchaseTokenCap.add(1))
      ).to.be.revertedWith("cap has been exceeded");
    });

    it("should fail when the pool is full and thus the purchase window is expired", async function () {
      const excess = 100;
      const maxPoolPurchase = await aelinPool.maxPoolPurchase();

      expect(maxPoolPurchase).to.equal(purchaseTokenCap);
      await purchaseToken
        .connect(user1)
        .approve(aelinPool.address, purchaseTokenCap.add(excess));
      await aelinPool.connect(user1).purchasePoolTokens(purchaseTokenCap);
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(excess)
      ).to.be.revertedWith("not in purchase window");
    });

    it("should fail when the deal has been created", async function () {
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await createDealWithValidParams();
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt)
      ).to.be.revertedWith("not in purchase window");
      const maxPoolPurchase = await aelinPool.maxPoolPurchase();
      expect(maxPoolPurchase).to.equal(0);
    });

    it("should require the pool to be in the purchase expiry window", async function () {
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt)
      ).to.be.revertedWith("not in purchase window");
    });
  });

  describe("purchase pool token setup", function () {
    beforeEach(async function () {
      await successfullyInitializePool();
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
    });
    // NOTE that most of the tests for this method will be in the
    // integration tests section since it needs to call a method
    // on the deal first in order to properly test
    describe("accept deal tokens", function () {
      it("should require the deal to be created", async function () {
        await expect(
          aelinPool.connect(user1).acceptMaxDealTokens()
        ).to.be.revertedWith("deal not yet created");
      });
    });

    describe("withdraw pool tokens", function () {
      it("should allow a purchaser to withdraw pool tokens", async function () {
        await ethers.provider.send("evm_increaseTime", [duration + 1]);
        await ethers.provider.send("evm_mine", []);

        await aelinPool.connect(user1).withdrawMaxFromPool();

        const [log] = await aelinPool.queryFilter(
          aelinPool.filters.WithdrawFromPool()
        );
        expect(log.args.purchaser).to.equal(user1.address);
        expect(log.args.poolAddress).to.equal(aelinPool.address);
        expect(log.args.purchaseTokenAmount).to.equal(userPurchaseAmt);
        expect(log.args.poolTokenAmount).to.equal(
          userPurchaseAmt.mul(
            Math.pow(10, poolTokenDecimals - purchaseTokenDecimals)
          )
        );
      });

      it("should allow the purchaser to withdraw a subset of their tokens", async function () {
        await ethers.provider.send("evm_increaseTime", [duration + 1]);
        await ethers.provider.send("evm_mine", []);

        const withdrawHalfPoolTokens = userPurchaseAmt
          .mul(Math.pow(10, poolTokenDecimals - purchaseTokenDecimals))
          .div(2);

        await aelinPool.connect(user1).withdrawFromPool(withdrawHalfPoolTokens);

        const [log] = await aelinPool.queryFilter(
          aelinPool.filters.WithdrawFromPool()
        );
        expect(log.args.purchaser).to.equal(user1.address);
        expect(log.args.poolAddress).to.equal(aelinPool.address);
        expect(log.args.purchaseTokenAmount).to.equal(userPurchaseAmt.div(2));
        expect(log.args.poolTokenAmount).to.equal(withdrawHalfPoolTokens);
      });

      it("should not allow the purchaser to withdraw more than their balance", async function () {
        await ethers.provider.send("evm_increaseTime", [duration + 1]);
        await ethers.provider.send("evm_mine", []);

        const doublePoolTokens = userPurchaseAmt
          .mul(Math.pow(10, poolTokenDecimals - purchaseTokenDecimals))
          .mul(2);

        await expect(
          aelinPool.connect(user1).withdrawFromPool(doublePoolTokens)
        ).to.be.reverted;
      });

      it("should not allow a purchaser to withdraw before the pool expiry is set", async function () {
        await expect(
          aelinPool.connect(user1).withdrawMaxFromPool()
        ).to.be.revertedWith("not yet withdraw period");
      });
    });
  });
});
