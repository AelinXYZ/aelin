import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { MockContract, solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import { AelinPool, AelinDeal, ERC20 } from "../../typechain";
import {
  fundUsers,
  getImpersonatedSigner,
  mockAelinRewardsAddress,
  nullAddress,
} from "../helpers";

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

  const purchaseTokenAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  const purchaseTokenWhaleAddress =
    "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let purchaseTokenWhaleSigner: SignerWithAddress;

  const userPurchaseBaseAmt = 400;
  const userPurchaseAmt = ethers.utils.parseUnits(
    userPurchaseBaseAmt.toString(),
    purchaseTokenDecimals
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
  const allowList: string[] = [];
  const allowListAmounts = [
    purchaseTokenCap,
    purchaseTokenCap.div(2),
    ethers.constants.MaxInt256,
  ];

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
    allowList[0] = deployer.address;
    allowList[1] = holder.address;
    allowList[2] = nonsponsor.address;

    purchaseTokenWhaleSigner = await getImpersonatedSigner(
      purchaseTokenWhaleAddress
    );
    await fundUsers(
      purchaseToken,
      purchaseTokenWhaleSigner,
      purchaseTokenCap.mul(10),
      [user1, nonsponsor, deployer, holder]
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
  // 2.5% sponsorFee
  const sponsorFee = ethers.utils.parseEther("2.5");
  const purchaseExpiry = 30 * 60 + 1; // 30min and 1sec
  const holderFundingExpiry = 30 * 60 + 1; // 30min and 1sec
  const aelinPoolName = `aePool-${name}`;
  const aelinPoolSymbol = `aeP-${symbol}`;

  const successfullyInitializePool = async ({ useAllowList = false }) => {
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
      mockAelinRewardsAddress,
      useAllowList ? allowList : [],
      useAllowList ? allowListAmounts : []
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
        holder.address,
        holderFundingExpiry
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
          mockAelinRewardsAddress,
          [],
          []
        )
      ).to.be.revertedWith("max 1 year duration");
    });

    it("should revert if purchase token is more than 18 decimals due to conversion issues", async function () {
      const mockTokenTooManyDecimals = await deployMockContract(
        holder,
        ERC20Artifact.abi
      );
      await mockTokenTooManyDecimals.mock.decimals.returns(19);
      await expect(
        aelinPool.initialize(
          name,
          symbol,
          purchaseTokenCap,
          mockTokenTooManyDecimals.address,
          365 * 24 * 60 * 60 - 100,
          sponsorFee,
          sponsor.address,
          purchaseExpiry,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
          [],
          []
        )
      ).to.be.revertedWith("too many token decimals");
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
          mockAelinRewardsAddress,
          [],
          []
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
          mockAelinRewardsAddress,
          [],
          []
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
          ethers.utils.parseEther("98.1"),
          sponsor.address,
          purchaseExpiry,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
          [],
          []
        )
      ).to.be.revertedWith("exceeds max sponsor fee");
    });

    it("should successfully initialize", async function () {
      const tx = await successfullyInitializePool({});

      expect(await aelinPool.name()).to.equal(aelinPoolName);
      expect(await aelinPool.symbol()).to.equal(aelinPoolSymbol);
      expect(await aelinPool.hasAllowList()).to.equal(false);
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
      const expectedPoolExpiry = timestamp + purchaseExpiry + duration;
      expect(await aelinPool.poolExpiry()).to.equal(expectedPoolExpiry);

      const expectedPurchaseExpiry = timestamp + purchaseExpiry;
      expect(await aelinPool.purchaseExpiry()).to.equal(expectedPurchaseExpiry);

      const [log] = await aelinPool.queryFilter(aelinPool.filters.SetSponsor());
      expect(log.args.sponsor).to.equal(sponsor.address);
    });

    it("should successfully initialize with an allow list", async function () {
      const tx = await successfullyInitializePool({ useAllowList: true });

      expect(await aelinPool.name()).to.equal(aelinPoolName);
      expect(await aelinPool.symbol()).to.equal(aelinPoolSymbol);
      expect(await aelinPool.purchaseTokenCap()).to.equal(purchaseTokenCap);
      expect(await aelinPool.hasAllowList()).to.equal(true);
      expect(await aelinPool.allowList(allowList[0])).to.equal(
        allowListAmounts[0]
      );
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
      const expectedPoolExpiry = timestamp + purchaseExpiry + duration;
      expect(await aelinPool.poolExpiry()).to.equal(expectedPoolExpiry);

      const expectedPurchaseExpiry = timestamp + purchaseExpiry;
      expect(await aelinPool.purchaseExpiry()).to.equal(expectedPurchaseExpiry);

      const [log] = await aelinPool.queryFilter(aelinPool.filters.SetSponsor());
      expect(log.args.sponsor).to.equal(sponsor.address);
    });

    it("should only allow initialization once", async function () {
      await successfullyInitializePool({});
      await expect(successfullyInitializePool({})).to.be.revertedWith(
        "can only initialize once"
      );
    });
  });

  describe("createDeal", async function () {
    it("should revert if pool is still in purchase mode", async function () {
      await successfullyInitializePool({});
      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("pool still in purchase mode");
    });

    it("should revert if redemption period is too short", async function () {
      await successfullyInitializePool({});
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
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");
    });

    it("should revert if redemption period is too long", async function () {
      await successfullyInitializePool({});
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
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("30 mins - 30 days for prorata");
    });

    it("should revert if null addresses are passing in for the holder or underlying token", async function () {
      await successfullyInitializePool({});
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
          nullAddress,
          holderFundingExpiry
        )
      ).to.be.revertedWith("cant pass null holder address");

      await expect(
        aelinPool.createDeal(
          nullAddress,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          30 * 24 * 60 * 60 + 1, // 1 second more than 30 days
          openRedemptionPeriod,
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("cant pass null token address");
    });

    it("should revert if vesting cliff is too long", async function () {
      await successfullyInitializePool({});
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          1825 * 24 * 60 * 60 + 1, // 1 second over maximum
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("max 5 year cliff");
    });

    it("should revert if vesting period is too long", async function () {
      await successfullyInitializePool({});
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          1825 * 24 * 60 * 60 + 1, // 1 second over maximum
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("max 5 year vesting");
    });

    it("should revert if the pool has no purchase tokens", async function () {
      await successfullyInitializePool({});
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "not enough funds available"
      );
    });

    it("should revert if the purchase total exceeds the pool balance", async function () {
      await successfullyInitializePool({});
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
      await successfullyInitializePool({});
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
            holder.address,
            holderFundingExpiry
          )
      ).to.be.revertedWith("only sponsor can access");
    });

    it("should fail when the open redemption period is too short or too long", async function () {
      // setup so that a user can purchase pool tokens
      await successfullyInitializePool({});
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
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("30 mins - 30 days for open");

      await expect(
        aelinPool.connect(sponsor).createDeal(
          underlyingDealToken.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          365 * 60 * 60 * 60, // more than 30 days
          holder.address,
          holderFundingExpiry
        )
      ).to.be.revertedWith("30 mins - 30 days for open");
    });

    it("should fail when the open redemption period is set when the totalSupply equals the deal purchase amount", async function () {
      await successfullyInitializePool({});
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
            holder.address,
            holderFundingExpiry
          )
      ).to.be.revertedWith("deal is 1:1, set open to 0");
    });

    it("should fail when the holder funding expiry is too long or too short", async function () {
      await successfullyInitializePool({});
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        aelinPool.connect(sponsor).createDeal(
          underlyingDealToken.address,
          userPurchaseAmt,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          holderFundingExpiry - 2 // less than 30 minutes
        )
      ).to.be.revertedWith("30 mins - 30 days for holder");

      await expect(
        aelinPool.connect(sponsor).createDeal(
          underlyingDealToken.address,
          userPurchaseAmt,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          365 * 60 * 60 * 60 // more than 30 days
        )
      ).to.be.revertedWith("30 mins - 30 days for holder");
    });

    it("should successfully create a deal", async function () {
      await successfullyInitializePool({});
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      const tx = await createDealWithValidParams();
      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);

      expect(await aelinPool.poolExpiry()).to.equal(timestamp);
      expect(await aelinPool.holderFundingExpiry()).to.equal(
        timestamp + holderFundingExpiry
      );
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
      expect(createDealLog.address).to.equal(aelinPool.address);

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
      expect(dealDetailsLog.args.holderFundingDuration).to.equal(
        holderFundingExpiry
      );

      await expect(createDealWithValidParams()).to.be.revertedWith(
        "cant create new deal"
      );
    });

    it("should allow a second deal if the first is not funded", async function () {
      await successfullyInitializePool({});
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await createDealWithValidParams();
      await ethers.provider.send("evm_increaseTime", [holderFundingExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(
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
            deployer.address,
            holderFundingExpiry
          )
      ).to.not.be.reverted;
      const [createDealLog, createDealLog2] = await aelinPool.queryFilter(
        aelinPool.filters.CreateDeal()
      );
      const [dealDetailsLog, dealDetailsLog2] = await aelinPool.queryFilter(
        aelinPool.filters.DealDetails()
      );

      expect(createDealLog.args.dealContract).to.be.properAddress;
      expect(createDealLog2.args.dealContract).to.be.properAddress;
      expect(createDealLog.args.dealContract).to.not.equal(
        createDealLog2.args.dealContract
      );
      expect(dealDetailsLog.args.holder).to.equal(holder.address);
      expect(dealDetailsLog2.args.holder).to.equal(deployer.address);
    });
  });

  describe("changing the sponsor", function () {
    beforeEach(async function () {
      await successfullyInitializePool({});
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

  describe("managing and purchasing with allow list", function () {
    it("should let the sponsor create an allow list", async function () {
      await successfullyInitializePool({ useAllowList: true });
      expect(await aelinPool.hasAllowList()).to.equal(true);
      expect(await aelinPool.allowList(allowList[0])).to.equal(
        allowListAmounts[0]
      );
    });

    it("should not allow an unlisted purchaser to enter the pool", async function () {
      await successfullyInitializePool({ useAllowList: true });
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt)
      ).to.be.revertedWith("more than allocation");
    });

    it("should not allow a purchaser on the allow list to enter the pool with too many funds", async function () {
      await successfullyInitializePool({ useAllowList: true });
      await purchaseToken
        .connect(holder)
        .approve(aelinPool.address, ethers.utils.parseEther("100"));
      await expect(
        aelinPool
          .connect(holder)
          .purchasePoolTokens(ethers.utils.parseEther("100"))
      ).to.be.revertedWith("more than allocation");
    });
    it("should allow a purchaser on the allow list to enter the pool", async function () {
      await successfullyInitializePool({ useAllowList: true });
      // nonsponsor has max capacity to invest in the uncapped pool
      await purchaseToken
        .connect(nonsponsor)
        .approve(aelinPool.address, allowListAmounts[2]);
      const totalBalance = await purchaseToken.balanceOf(nonsponsor.address);
      const amount = totalBalance.gt(purchaseTokenCap)
        ? purchaseTokenCap
        : totalBalance;
      await aelinPool.connect(nonsponsor).purchasePoolTokens(amount);

      const [log] = await aelinPool.queryFilter(
        aelinPool.filters.PurchasePoolToken()
      );

      expect(log.args.purchaser).to.equal(nonsponsor.address);
      expect(log.address).to.equal(aelinPool.address);
      expect(log.args.purchaseTokenAmount).to.equal(amount);
    });
  });

  describe("purchase pool tokens", function () {
    beforeEach(async function () {
      await successfullyInitializePool({});
    });

    it("should successfully purchase pool tokens for the user", async function () {
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
      const [log] = await aelinPool.queryFilter(
        aelinPool.filters.PurchasePoolToken()
      );

      expect(log.args.purchaser).to.equal(user1.address);
      expect(log.address).to.equal(aelinPool.address);
      expect(log.args.purchaseTokenAmount).to.equal(userPurchaseAmt);
    });

    it("should fail the transaction when the cap has been exceeded", async function () {
      await purchaseToken
        .connect(user1)
        .approve(aelinPool.address, purchaseTokenCap.add(1));
      await expect(
        aelinPool.connect(user1).purchasePoolTokens(purchaseTokenCap.add(1))
      ).to.be.revertedWith("cap has been exceeded");
    });

    it("should fail when the pool is full and thus the purchase window is expired", async function () {
      const excess = 100;
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
      await successfullyInitializePool({});
      await aelinPool.connect(user1).purchasePoolTokens(userPurchaseAmt);
    });
    // NOTE that most of the tests for this method will be in the
    // integration tests section since it needs to call a method
    // on the deal first in order to properly test
    describe("accept deal tokens", function () {
      it("should require the deal to be created", async function () {
        await expect(
          aelinPool.connect(user1).acceptMaxDealTokens()
        ).to.be.revertedWith("deal not yet funded");
      });
    });

    describe("withdraw pool tokens", function () {
      it("should allow a purchaser to withdraw pool tokens", async function () {
        await ethers.provider.send("evm_increaseTime", [
          purchaseExpiry + duration + 1,
        ]);
        await ethers.provider.send("evm_mine", []);

        await aelinPool.connect(user1).withdrawMaxFromPool();

        const [log] = await aelinPool.queryFilter(
          aelinPool.filters.WithdrawFromPool()
        );
        expect(log.args.purchaser).to.equal(user1.address);
        expect(log.address).to.equal(aelinPool.address);
        expect(log.args.purchaseTokenAmount).to.equal(userPurchaseAmt);
      });

      it("should allow the purchaser to withdraw a subset of their tokens", async function () {
        await ethers.provider.send("evm_increaseTime", [
          purchaseExpiry + duration + 1,
        ]);
        await ethers.provider.send("evm_mine", []);

        const withdrawHalfPoolTokens = userPurchaseAmt.div(2);

        await aelinPool.connect(user1).withdrawFromPool(withdrawHalfPoolTokens);

        const [log] = await aelinPool.queryFilter(
          aelinPool.filters.WithdrawFromPool()
        );
        expect(log.args.purchaser).to.equal(user1.address);
        expect(log.address).to.equal(aelinPool.address);
        expect(log.args.purchaseTokenAmount).to.equal(withdrawHalfPoolTokens);
      });

      it("should not allow the purchaser to withdraw more than their balance", async function () {
        await ethers.provider.send("evm_increaseTime", [duration + 1]);
        await ethers.provider.send("evm_mine", []);

        const doublePurchaseTokens = userPurchaseAmt.mul(2);

        await expect(
          aelinPool.connect(user1).withdrawFromPool(doublePurchaseTokens)
        ).to.be.reverted;
      });

      it("should not allow a purchaser to withdraw before the pool expiry is set", async function () {
        await expect(
          aelinPool.connect(user1).withdrawMaxFromPool()
        ).to.be.revertedWith("not yet withdraw period");
      });

      it("should not allow a purchaser to withdraw in the funding period", async function () {
        await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
        await ethers.provider.send("evm_mine", []);

        await createDealWithValidParams();
        await expect(
          aelinPool.connect(user1).withdrawMaxFromPool()
        ).to.be.revertedWith("cant withdraw in funding period");
      });
    });
  });
});
