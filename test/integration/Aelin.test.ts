import chai, { expect } from "chai";
import { ethers, network, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { solidity } from "ethereum-waffle";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";

import { AelinPool, AelinDeal, AelinPoolFactory, ERC20 } from "../../typechain";

const { deployContract } = waffle;

chai.use(solidity);

describe("integration test", () => {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;
  let user5: SignerWithAddress;
  let aelinPoolProxyStorage: AelinPool;
  let aelinDealProxyStorage: AelinDeal;
  let aelinPoolLogic: AelinPool;
  let aelinDealLogic: AelinDeal;
  let aelinPoolFactory: AelinPoolFactory;
  const dealOrPoolTokenDecimals = 18;

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;
  const usdcDecimals = 6;

  const purchaseAmount = ethers.utils.parseUnits("5000", usdcDecimals);
  const poolAmount = ethers.utils.parseUnits("5000", dealOrPoolTokenDecimals);

  const aaveContractAddress = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9";
  let aaveContract: ERC20;
  const aaveDecimals = 18;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  const aaveWhaleAddress = "0x73f9B272aBda7A97CB1b237D85F9a7236EDB6F16";
  let aaveWhale: SignerWithAddress;

  const fundUSDCAmount = ethers.utils.parseUnits("100000", usdcDecimals);
  const fundUsdcToUsers = async (users: SignerWithAddress[]) => {
    users.forEach((user) => {
      usdcContract
        .connect(usdcWhaleSigner)
        .transfer(user.address, fundUSDCAmount);
    });
  };

  const getImpersonatedSigner = async (
    address: string
  ): Promise<SignerWithAddress> => {
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [address],
    });

    return ethers.getSigner(address);
  };

  before(async () => {
    [deployer, sponsor, user1, user2, user3, user4, user5] =
      await ethers.getSigners();

    usdcContract = (await ethers.getContractAt(
      ERC20Artifact.abi,
      usdcContractAddress
    )) as ERC20;

    aaveContract = (await ethers.getContractAt(
      ERC20Artifact.abi,
      aaveContractAddress
    )) as ERC20;

    usdcWhaleSigner = await getImpersonatedSigner(usdcWhaleAddress);
    aaveWhale = await getImpersonatedSigner(aaveWhaleAddress);

    // NOTE that the deploy method for aelin pool exceeds the default hardhat 3M gas limit
    // and aelin deal is close to the limit
    await ethers.provider.send("evm_setBlockGasLimit", [
      `0x${ethers.BigNumber.from(6000000)}`,
    ]);
    await ethers.provider.send("evm_mine", []);

    aelinDealLogic = (await deployContract(
      deployer,
      AelinDealArtifact
    )) as AelinDeal;

    aelinPoolLogic = (await deployContract(
      deployer,
      AelinPoolArtifact
    )) as AelinPool;

    aelinPoolFactory = (await deployContract(
      deployer,
      AelinPoolFactoryArtifact
    )) as AelinPoolFactory;

    await fundUsdcToUsers([user1, user2, user3, user4, user5]);
  });

  const oneYear = 365 * 24 * 60 * 60; // one year
  const name = "Pool name";
  const symbol = "POOL";
  const purchaseTokenCap = ethers.utils.parseUnits("22500", usdcDecimals);
  const duration = oneYear;
  const sponsorFee = 3000; // 0 to 98 represents 0 to 98%
  const base = 100000; // hardcoded in the contracts
  const aelinFee = 2000; // hardcoded in the contracts
  const purchaseExpiry = 30 * 24 * 60 * 60; // one month

  const purchaseTokenTotalForDeal = ethers.utils.parseUnits(
    "20000",
    usdcDecimals
  );
  // one AAVE is $300
  const underlyingDealTokenTotal = ethers.utils.parseUnits("50", aaveDecimals);
  const vestingPeriod = oneYear;
  const vestingCliff = oneYear;
  const proRataRedemptionPeriod = 7 * 24 * 60 * 60; // one week
  const openRedemptionPeriod = 24 * 60 * 60; // one day

  describe("capped pool success workflow", function () {
    it(`
    1. creates a capped pool
    2. gets fully funded by purchasers
    3. the deal is created and then funded
    4. some, but not all, of the pool accepts and the deal expires
    5. the holder withdraws unaccepted tokens
    6. the tokens fully vest and are claimed
  `, async () => {
      await aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseTokenCap,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry,
          aelinPoolLogic.address,
          aelinDealLogic.address
        );

      const [createPoolLog] = await aelinPoolFactory.queryFilter(
        aelinPoolFactory.filters.CreatePool()
      );

      // partial check of logs. already testing all logs in unit tests
      expect(createPoolLog.args.poolAddress).to.be.properAddress;
      expect(createPoolLog.args.name).to.equal("aePool-" + name);

      aelinPoolProxyStorage = (await ethers.getContractAt(
        AelinPoolArtifact.abi,
        createPoolLog.args.poolAddress
      )) as AelinPool;

      const feesNumerator = ethers.BigNumber.from(
        base - (aelinFee + sponsorFee)
      );
      const feesDenominator = ethers.BigNumber.from(base);

      expect(await usdcContract.balanceOf(user1.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user2.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user3.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user4.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user5.address)).to.equal(
        fundUSDCAmount
      );

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user1)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);
      await usdcContract
        .connect(user2)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);
      await usdcContract
        .connect(user3)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);
      await usdcContract
        .connect(user4)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);
      await usdcContract
        .connect(user5)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);

      // purchasers buy pool tokens
      await aelinPoolProxyStorage
        .connect(user1)
        .purchasePoolTokens(purchaseAmount);
      await aelinPoolProxyStorage
        .connect(user2)
        .purchasePoolTokens(purchaseAmount);
      await aelinPoolProxyStorage
        .connect(user3)
        .purchasePoolTokens(purchaseAmount);
      await aelinPoolProxyStorage
        .connect(user4)
        .purchasePoolTokens(purchaseAmount);
      // user 5 only gets 2500 at the end
      // NOTE do we want them to get the remaining or nothing at all if they don't pass the exact amount???
      await aelinPoolProxyStorage
        .connect(user5)
        .purchasePoolTokens(purchaseAmount.div(2));

      // checks pool balance is accurate
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user2.address)).to.equal(
        poolAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user3.address)).to.equal(
        poolAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user4.address)).to.equal(
        poolAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user5.address)).to.equal(
        poolAmount.div(2)
      );

      // checks USDC balance is accurate
      expect(await usdcContract.balanceOf(user1.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount)
      );
      expect(await usdcContract.balanceOf(user2.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount)
      );
      expect(await usdcContract.balanceOf(user3.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount)
      );
      expect(await usdcContract.balanceOf(user4.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount)
      );
      expect(await usdcContract.balanceOf(user5.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount.div(2))
      );

      await aelinPoolProxyStorage
        .connect(sponsor)
        .createDeal(
          aaveContract.address,
          purchaseTokenTotalForDeal,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          aaveWhale.address
        );

      const [createDealLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      expect(createDealLog.args.dealContract).to.be.properAddress;
      expect(createDealLog.args.name).to.equal("aeDeal-" + name);

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealLog.args.dealContract
      )) as AelinDeal;

      // user 3 withdraws 500 from the pool leaving 2000 remaining
      await aelinPoolProxyStorage
        .connect(user3)
        .withdrawFromPool(
          ethers.utils.parseUnits("2500", dealOrPoolTokenDecimals)
        );
      // checks pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user3.address)).to.equal(
        poolAmount.div(2)
      );
      // checks USDC balance
      expect(await usdcContract.balanceOf(user3.address)).to.equal(
        fundUSDCAmount.sub(purchaseAmount.div(2))
      );

      // user 3 then withdraws the remainder of their funds
      await aelinPoolProxyStorage.connect(user3).withdrawMaxFromPool();
      // checks pool balance is 0
      expect(await aelinPoolProxyStorage.balanceOf(user3.address)).to.equal(0);
      // checks all USDC has been refunded
      expect(await usdcContract.balanceOf(user3.address)).to.equal(
        fundUSDCAmount
      );

      await aaveContract
        .connect(aaveWhale)
        .approve(
          aelinDealProxyStorage.address,
          underlyingDealTokenTotal.add(1)
        );

      await aelinDealProxyStorage
        .connect(aaveWhale)
        .depositUnderlying(underlyingDealTokenTotal.add(1));

      // checks deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenTotal.add(1));

      // withdraws the extra 1
      await aelinDealProxyStorage.connect(aaveWhale).withdraw();

      // checks updated deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenTotal);

      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user2.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user3.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user4.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user5.address)).to.equal(0);

      const user1ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user1.address
      );
      // 5000 is transferred to the holder
      await aelinPoolProxyStorage.connect(user1).acceptMaxDealTokens();

      // checks holder USDC balance
      // TODO it wont equal purchase amount it will be the max pro rata avail for the user :)
      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
        user1ProRataAvail.div(
          Math.pow(10, dealOrPoolTokenDecimals - usdcDecimals)
        )
      );
      // checks user 1 pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount.sub(user1ProRataAvail)
      );

      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(
        user1ProRataAvail.mul(feesNumerator).div(feesDenominator)
      );

      const user2ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user2.address
      );

      await aelinPoolProxyStorage.connect(user2).acceptMaxDealTokens();

      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
        user2ProRataAvail
          .add(user1ProRataAvail)
          .div(Math.pow(10, dealOrPoolTokenDecimals - usdcDecimals))
      );
      expect(await aelinDealProxyStorage.balanceOf(user2.address)).to.equal(
        user2ProRataAvail.mul(feesNumerator).div(feesDenominator)
      );

      // confirm user 3 has no balance left
      const user3ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user3.address
      );
      expect(user3ProRataAvail).to.equal(0);

      const user4ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user4.address
      );

      await aelinPoolProxyStorage
        .connect(user4)
        .acceptDealTokens(user4ProRataAvail);

      expect(await aelinDealProxyStorage.balanceOf(user5.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user4.address)).to.equal(
        user4ProRataAvail.mul(feesNumerator).div(feesDenominator)
      );

      // NOTE the sub 1 is accurate and due to precision loss during conversion
      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
        user2ProRataAvail
          .add(user1ProRataAvail)
          .add(user4ProRataAvail)
          .div(Math.pow(10, dealOrPoolTokenDecimals - usdcDecimals))
          .sub(1)
      );
      const user5ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user5.address
      );

      await aelinPoolProxyStorage
        .connect(user5)
        .acceptDealTokens(user5ProRataAvail);

      expect(await aelinDealProxyStorage.balanceOf(user5.address)).to.equal(
        user5ProRataAvail.mul(feesNumerator).div(feesDenominator)
      );

      // NOTE the sub 1 is accurate and due to precision loss during conversion
      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
        user2ProRataAvail
          .add(user1ProRataAvail)
          .add(user4ProRataAvail)
          .add(user5ProRataAvail)
          .div(Math.pow(10, dealOrPoolTokenDecimals - usdcDecimals))
          .sub(1)
      );

      const acceptLogs = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.AcceptDeal()
      );
      expect(acceptLogs.length).to.equal(4);

      const mintLogs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.MintDealTokens()
      );
      expect(mintLogs.length).to.equal(4 * 3);

      const totalToHolderFromEvents = acceptLogs.reduce(
        (acc, log) => acc.add(log.args.underlyingToHolderAmt),
        ethers.BigNumber.from(0)
      );
      expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
        totalToHolderFromEvents
      );

      // TODO add in increase to the open redemption period and have the users claim the rest
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.not.equal(
        0
      );
      await aelinPoolProxyStorage.connect(user1).acceptMaxDealTokens();

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(0);

      await ethers.provider.send("evm_increaseTime", [
        openRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      await aelinDealProxyStorage.connect(aaveWhale).withdrawExpiry();

      await ethers.provider.send("evm_increaseTime", [
        vestingCliff + vestingPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user4.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user5.address)).to.equal(0);

      await aelinDealProxyStorage.connect(user2).claim(user1.address);
      await aelinDealProxyStorage.connect(user2).claim(user2.address);
      await aelinDealProxyStorage.connect(user4).claim(user5.address);

      const logs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.ClaimedUnderlyingDealTokens()
      );

      // TODO calculate exact claim amount
      expect(await aaveContract.balanceOf(user1.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user2.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user4.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user5.address)).to.not.equal(0);

      expect(await aaveContract.balanceOf(user1.address)).to.equal(
        logs[0].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user2.address)).to.equal(
        logs[1].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user5.address)).to.equal(
        logs[2].args.underlyingDealTokensClaimed
      );
    });
  });

  // describe("uncapped pool success workflow", function () {
  //   it(`
  //   1. creates an uncapped pool
  //   2. gets funded by purchasers
  //   3. the deal is created and then funded
  //   4. some, but not all, of the pool accepts and the deal expires
  //   5. the holder withdraws unaccepted tokens
  //   6. the tokens fully vest and are claimed
  // `, async () => {});
  // });

  describe("transfer blocked in redeem window", function () {
    let poolFactory: AelinPoolFactory;

    beforeEach(async function () {
      poolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact
      )) as AelinPoolFactory;

      await poolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseAmount,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry,
          aelinPoolLogic.address,
          aelinDealLogic.address
        );

      const [createPoolLog] = await poolFactory.queryFilter(
        poolFactory.filters.CreatePool()
      );

      aelinPoolProxyStorage = (await ethers.getContractAt(
        AelinPoolArtifact.abi,
        createPoolLog.args.poolAddress
      )) as AelinPool;

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user1)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);

      // purchasers buy pool tokens
      await aelinPoolProxyStorage
        .connect(user1)
        .purchasePoolTokens(purchaseAmount);

      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await aelinPoolProxyStorage
        .connect(sponsor)
        .createDeal(
          aaveContract.address,
          purchaseAmount.div(4),
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          aaveWhale.address
        );

      const [createDealLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealLog.args.dealContract
      )) as AelinDeal;
    });

    it("should allow the user to transfer before the redeem window", async function () {
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount
      );
      await aelinPoolProxyStorage
        .connect(user1)
        .transfer(user2.address, poolAmount);
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(0);
      expect(await aelinPoolProxyStorage.balanceOf(user2.address)).to.equal(
        poolAmount
      );
    });

    it("should block a transfer during the redeem window", async function () {
      await aaveContract
        .connect(aaveWhale)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhale)
        .depositUnderlying(underlyingDealTokenTotal);

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount
      );
      await expect(
        aelinPoolProxyStorage.connect(user1).transfer(user2.address, poolAmount)
      ).to.be.revertedWith("no transfers after redeem starts");
    });

    it("should block a transferFrom during the redeem window", async function () {
      await aaveContract
        .connect(aaveWhale)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhale)
        .depositUnderlying(underlyingDealTokenTotal);

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount
      );
      await expect(
        aelinPoolProxyStorage
          .connect(user1)
          .transferFrom(user1.address, user2.address, poolAmount)
      ).to.be.revertedWith("no transfers after redeem starts");
    });
  });

  describe.skip("accept deal tests", function () {
    let poolFactory: AelinPoolFactory;

    beforeEach(async function () {
      poolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact
      )) as AelinPoolFactory;

      await poolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseAmount,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry,
          aelinPoolLogic.address,
          aelinDealLogic.address
        );

      const [createPoolLog] = await poolFactory.queryFilter(
        poolFactory.filters.CreatePool()
      );

      aelinPoolProxyStorage = (await ethers.getContractAt(
        AelinPoolArtifact.abi,
        createPoolLog.args.poolAddress
      )) as AelinPool;

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user1)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);

      // purchasers buy pool tokens
      await aelinPoolProxyStorage
        .connect(user1)
        .purchasePoolTokens(purchaseAmount);

      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await aelinPoolProxyStorage
        .connect(sponsor)
        .createDeal(
          aaveContract.address,
          purchaseAmount.div(4),
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          aaveWhale.address
        );

      const [createDealLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealLog.args.dealContract
      )) as AelinDeal;

      await aaveContract
        .connect(aaveWhale)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhale)
        .depositUnderlying(underlyingDealTokenTotal);
    });
    it("should accept max deal tokens", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(0);
      await aelinPoolProxyStorage.connect(user1).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount
      );
    });
    it("should accept partial deal tokens", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(0);
      await aelinPoolProxyStorage
        .connect(user1)
        .acceptDealTokens(poolAmount.div(2));
      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(
        poolAmount.div(2)
      );
    });
  });
});
