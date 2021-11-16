import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { solidity } from "ethereum-waffle";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";

import { AelinPool, AelinDeal, AelinPoolFactory, ERC20 } from "../../typechain";
import {
  fundUsers,
  getImpersonatedSigner,
  mockAelinRewardsAddress,
} from "../helpers";
const nullAddress = "0x0000000000000000000000000000000000000000";

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
  let user6: SignerWithAddress;
  let user7: SignerWithAddress;
  let user8: SignerWithAddress;
  let user9: SignerWithAddress;
  let user10: SignerWithAddress;
  let user11: SignerWithAddress;
  let user12: SignerWithAddress;
  let aelinPoolProxyStorage: AelinPool;
  let aelinDealProxyStorage: AelinDeal;
  let aelinPoolLogic: AelinPool;
  let aelinDealLogic: AelinDeal;
  const dealTokenDecimals = 18;

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;
  const usdcDecimals = 6;

  const uncappedPurchaseAmount = ethers.utils.parseUnits(
    "100000",
    usdcDecimals
  );
  const purchaseAmount = ethers.utils.parseUnits("5000", usdcDecimals);
  const dealTokenAmount = ethers.utils.parseUnits("5000", dealTokenDecimals);

  const aaveContractAddress = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9";
  let aaveContract: ERC20;
  const aaveDecimals = 18;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  const aaveWhaleAddressOne = "0x73f9B272aBda7A97CB1b237D85F9a7236EDB6F16";
  const aaveWhaleAddressTwo = "0xAd18FC2cfB141BF64Dd64B9eB99616b5b2b92AbD";
  let aaveWhaleOne: SignerWithAddress;
  let aaveWhaleTwo: SignerWithAddress;

  const fundUSDCAmount = ethers.utils.parseUnits("100000", usdcDecimals);

  before(async () => {
    [
      deployer,
      sponsor,
      user1,
      user2,
      user3,
      user4,
      user5,
      user6,
      user7,
      user8,
      user9,
      user10,
      user11,
      user12,
    ] = await ethers.getSigners();

    usdcContract = (await ethers.getContractAt(
      ERC20Artifact.abi,
      usdcContractAddress
    )) as ERC20;

    aaveContract = (await ethers.getContractAt(
      ERC20Artifact.abi,
      aaveContractAddress
    )) as ERC20;

    usdcWhaleSigner = await getImpersonatedSigner(usdcWhaleAddress);
    aaveWhaleOne = await getImpersonatedSigner(aaveWhaleAddressOne);
    aaveWhaleTwo = await getImpersonatedSigner(aaveWhaleAddressTwo);

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
    await fundUsers(usdcContract, usdcWhaleSigner, fundUSDCAmount, [
      user1,
      user2,
      user3,
      user4,
      user5,
      user6,
      user7,
      user8,
      user9,
      user10,
      user11,
      user12,
    ]);
  });

  const oneYear = 365 * 24 * 60 * 60; // one year
  const name = "Pool name";
  const symbol = "POOL";
  const purchaseTokenCap = ethers.utils.parseUnits("22500", usdcDecimals);
  const duration = oneYear;
  const sponsorFee = ethers.utils.parseEther("3"); // 0 to 98 represents 0 to 98%
  const base = ethers.utils.parseEther("100"); // hardcoded in the contracts
  const purchaseExpiry = 30 * 24 * 60 * 60; // one month
  const holderFundingExpiry = 30 * 24 * 60 * 60; // one month
  const feesNumerator = ethers.utils.parseEther("95"); // base - (aelinFee + sponsorFee)

  const purchaseTokenTotalForUncappedDeal = ethers.utils.parseUnits(
    "225000",
    usdcDecimals
  );

  const purchaseTokenTotalForDeal = ethers.utils.parseUnits(
    "20000",
    usdcDecimals
  );
  // one AAVE is $300
  const underlyingDealTokenUncappedTotal = ethers.utils.parseUnits(
    "225",
    aaveDecimals
  );
  const underlyingDealTokenTotal = ethers.utils.parseUnits("50", aaveDecimals);
  const vestingPeriod = oneYear;
  const vestingCliff = oneYear;
  const proRataRedemptionPeriod = 7 * 24 * 60 * 60; // one week
  const openRedemptionPeriod = 24 * 60 * 60; // one day

  describe("test capped and uncapped pools", function () {
    it(`
    1. creates a capped pool
    2. gets fully funded by purchasers
    3. the deal is created
    4. the holder only partially funds the deposit
    5. the deal expires and then the holder withdraws their funds
    6. a new deal is created and funded
    7. some, but not all, of the pool accepts and the deal expires
    8. the holder withdraws unaccepted tokens
    9. the tokens fully vest and are claimed
  `, async () => {
      const aelinPoolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact,
        [
          aelinPoolLogic.address,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
        ]
      )) as AelinPoolFactory;

      await aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseTokenCap,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry
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
        purchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user2.address)).to.equal(
        purchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user3.address)).to.equal(
        purchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user4.address)).to.equal(
        purchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user5.address)).to.equal(
        purchaseAmount.div(2)
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

      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

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
          aaveWhaleTwo.address,
          holderFundingExpiry
        );
      const [createDealOneLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealOneLog.args.dealContract
      )) as AelinDeal;

      // the first holder only deposits half and misses the deadline and then
      // will withdraw their half after the deadline.
      await aaveContract
        .connect(aaveWhaleTwo)
        .approve(
          aelinDealProxyStorage.address,
          underlyingDealTokenTotal.div(2)
        );

      await aelinDealProxyStorage
        .connect(aaveWhaleTwo)
        .depositUnderlying(underlyingDealTokenTotal.div(2));

      // checks deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenTotal.div(2));

      await ethers.provider.send("evm_increaseTime", [holderFundingExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await aelinDealProxyStorage.connect(aaveWhaleTwo).withdraw();

      // checks updated deal underlying balance is 0
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(0);

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
          aaveWhaleOne.address,
          holderFundingExpiry
        );

      const [, createDealTwoLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      expect(createDealTwoLog.args.dealContract).to.be.properAddress;
      expect(createDealTwoLog.args.name).to.equal("aeDeal-" + name);

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealTwoLog.args.dealContract
      )) as AelinDeal;

      await aaveContract
        .connect(aaveWhaleOne)
        .approve(
          aelinDealProxyStorage.address,
          underlyingDealTokenTotal.add(1)
        );

      await aelinDealProxyStorage
        .connect(aaveWhaleOne)
        .depositUnderlying(underlyingDealTokenTotal.add(1));

      // checks deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenTotal.add(1));

      // withdraws the extra 1
      await aelinDealProxyStorage.connect(aaveWhaleOne).withdraw();

      // user 3 withdraws 500 from the pool leaving 2000 remaining
      await aelinPoolProxyStorage
        .connect(user3)
        .withdrawFromPool(ethers.utils.parseUnits("2500", usdcDecimals));
      // checks pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user3.address)).to.equal(
        purchaseAmount.div(2)
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

      // checks updated deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenTotal);

      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(0);
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
      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(
        user1ProRataAvail
      );
      // checks user 1 pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        purchaseAmount.sub(user1ProRataAvail)
      );

      expect(await aelinDealProxyStorage.balanceOf(user1.address)).to.equal(
        user1ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      const user2ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user2.address
      );

      await aelinPoolProxyStorage.connect(user2).acceptMaxDealTokens();

      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(
        user2ProRataAvail.add(user1ProRataAvail)
      );
      expect(await aelinDealProxyStorage.balanceOf(user2.address)).to.equal(
        user2ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
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
        user4ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(
        user2ProRataAvail.add(user1ProRataAvail).add(user4ProRataAvail)
      );
      const user5ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user5.address
      );

      await aelinPoolProxyStorage
        .connect(user5)
        .acceptDealTokens(user5ProRataAvail);

      expect(await aelinDealProxyStorage.balanceOf(user5.address)).to.equal(
        user5ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      // NOTE the sub 1 is accurate and due to precision loss during conversion
      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(
        user2ProRataAvail
          .add(user1ProRataAvail)
          .add(user4ProRataAvail)
          .add(user5ProRataAvail)
      );

      const acceptLogs = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.AcceptDeal()
      );
      expect(acceptLogs.length).to.equal(4);

      const mintLogs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.Transfer(nullAddress)
      );

      expect(mintLogs.length).to.equal(4 * 3);

      const totalToHolderFromEvents = acceptLogs.reduce(
        (acc, log) => acc.add(log.args.poolTokenAmount),
        ethers.BigNumber.from(0)
      );
      expect(await usdcContract.balanceOf(aaveWhaleOne.address)).to.equal(
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

      await aelinDealProxyStorage.connect(aaveWhaleOne).withdrawExpiry();

      await ethers.provider.send("evm_increaseTime", [
        vestingCliff + vestingPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user4.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user5.address)).to.equal(0);

      await aelinDealProxyStorage.connect(user1).claim();
      await aelinDealProxyStorage.connect(user2).claim();
      await aelinDealProxyStorage.connect(user4).claim();
      await aelinDealProxyStorage.connect(user5).claim();

      const logs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.ClaimedUnderlyingDealTokens()
      );
      // TODO calculate exact claim amount
      expect(await aaveContract.balanceOf(user1.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user2.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user4.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user5.address)).to.not.equal(0);

      expect(await aaveContract.balanceOf(user1.address)).to.equal(
        logs[0].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user2.address)).to.equal(
        logs[1].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user4.address)).to.equal(
        logs[2].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user5.address)).to.equal(
        logs[3].args.underlyingDealTokensClaimed
      );
    });

    it(`
    1. creates an uncapped pool
    2. gets funded by purchasers
    3. the deal is created and then funded
    4. some, but not all, of the pool accepts and the deal expires
    5. the holder withdraws unaccepted tokens
    6. the tokens fully vest and are claimed
  `, async () => {
      const aelinPoolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact,
        [
          aelinPoolLogic.address,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
        ]
      )) as AelinPoolFactory;

      await aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          0,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry
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

      expect(await usdcContract.balanceOf(user6.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user7.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user8.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user9.address)).to.equal(
        fundUSDCAmount
      );
      expect(await usdcContract.balanceOf(user10.address)).to.equal(
        fundUSDCAmount
      );

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user6)
        .approve(aelinPoolProxyStorage.address, uncappedPurchaseAmount);
      await usdcContract
        .connect(user7)
        .approve(aelinPoolProxyStorage.address, uncappedPurchaseAmount);
      await usdcContract
        .connect(user8)
        .approve(aelinPoolProxyStorage.address, uncappedPurchaseAmount);
      await usdcContract
        .connect(user9)
        .approve(aelinPoolProxyStorage.address, uncappedPurchaseAmount);
      await usdcContract
        .connect(user10)
        .approve(aelinPoolProxyStorage.address, uncappedPurchaseAmount);

      // purchasers buy pool tokens
      await aelinPoolProxyStorage
        .connect(user6)
        .purchasePoolTokens(uncappedPurchaseAmount);
      await aelinPoolProxyStorage
        .connect(user7)
        .purchasePoolTokens(uncappedPurchaseAmount);
      await aelinPoolProxyStorage
        .connect(user8)
        .purchasePoolTokens(uncappedPurchaseAmount);
      await aelinPoolProxyStorage
        .connect(user9)
        .purchasePoolTokens(uncappedPurchaseAmount);
      await aelinPoolProxyStorage
        .connect(user10)
        .purchasePoolTokens(uncappedPurchaseAmount.div(2));

      // checks pool balance is accurate
      expect(await aelinPoolProxyStorage.balanceOf(user6.address)).to.equal(
        uncappedPurchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user7.address)).to.equal(
        uncappedPurchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user8.address)).to.equal(
        uncappedPurchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user9.address)).to.equal(
        uncappedPurchaseAmount
      );
      expect(await aelinPoolProxyStorage.balanceOf(user10.address)).to.equal(
        uncappedPurchaseAmount.div(2)
      );

      // checks USDC balance is accurate
      expect(await usdcContract.balanceOf(user6.address)).to.equal(0);
      expect(await usdcContract.balanceOf(user7.address)).to.equal(0);
      expect(await usdcContract.balanceOf(user8.address)).to.equal(0);
      expect(await usdcContract.balanceOf(user9.address)).to.equal(0);
      expect(await usdcContract.balanceOf(user10.address)).to.equal(
        fundUSDCAmount.div(2)
      );

      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      // 50% conversion rate - 450K but only 225K allowed
      // gets 225 aave all in
      await aelinPoolProxyStorage
        .connect(sponsor)
        .createDeal(
          aaveContract.address,
          purchaseTokenTotalForUncappedDeal,
          underlyingDealTokenUncappedTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          aaveWhaleTwo.address,
          holderFundingExpiry
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

      await aaveContract
        .connect(aaveWhaleTwo)
        .approve(
          aelinDealProxyStorage.address,
          underlyingDealTokenUncappedTotal.add(1)
        );

      await aelinDealProxyStorage
        .connect(aaveWhaleTwo)
        .depositUnderlying(underlyingDealTokenUncappedTotal.add(1));

      // checks deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenUncappedTotal.add(1));

      // withdraws the extra 1
      await aelinDealProxyStorage.connect(aaveWhaleTwo).withdraw();

      // checks updated deal underlying balance
      expect(
        await aaveContract.balanceOf(aelinDealProxyStorage.address)
      ).to.equal(underlyingDealTokenUncappedTotal);

      // user 8 withdraws 50000 from the pool leaving 50000 remaining
      await aelinPoolProxyStorage
        .connect(user8)
        .withdrawFromPool(ethers.utils.parseUnits("50000", usdcDecimals));
      // checks pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user8.address)).to.equal(
        uncappedPurchaseAmount.div(2)
      );
      // checks USDC balance
      expect(await usdcContract.balanceOf(user8.address)).to.equal(
        fundUSDCAmount.div(2)
      );

      // user 3 then withdraws the remainder of their funds
      await aelinPoolProxyStorage.connect(user8).withdrawMaxFromPool();
      // checks pool balance is 0
      expect(await aelinPoolProxyStorage.balanceOf(user8.address)).to.equal(0);
      // checks all USDC has been refunded
      expect(await usdcContract.balanceOf(user8.address)).to.equal(
        fundUSDCAmount
      );

      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user6.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user7.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user8.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user9.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user10.address)).to.equal(0);

      const user6ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user6.address
      );
      // 5000 is transferred to the holder
      await aelinPoolProxyStorage.connect(user6).acceptMaxDealTokens();

      // checks holder USDC balance
      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(
        user6ProRataAvail
      );
      // checks user 6 pool balance
      expect(await aelinPoolProxyStorage.balanceOf(user6.address)).to.equal(
        uncappedPurchaseAmount.sub(user6ProRataAvail)
      );
      // checks user 6 deal balance
      expect(await aelinDealProxyStorage.balanceOf(user6.address)).to.equal(
        user6ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      const user7ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user7.address
      );

      await aelinPoolProxyStorage.connect(user7).acceptMaxDealTokens();

      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(
        user7ProRataAvail.add(user6ProRataAvail)
      );
      expect(await aelinDealProxyStorage.balanceOf(user7.address)).to.equal(
        user7ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      // confirm user 8 has no balance left
      expect(
        await aelinPoolProxyStorage.maxProRataAvail(user8.address)
      ).to.equal(0);

      const user9ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user9.address
      );

      await aelinPoolProxyStorage
        .connect(user9)
        .acceptDealTokens(user9ProRataAvail);

      expect(await aelinDealProxyStorage.balanceOf(user10.address)).to.equal(0);
      expect(await aelinDealProxyStorage.balanceOf(user9.address)).to.equal(
        user9ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(
        user7ProRataAvail.add(user6ProRataAvail).add(user9ProRataAvail)
      );
      const user10ProRataAvail = await aelinPoolProxyStorage.maxProRataAvail(
        user10.address
      );

      await aelinPoolProxyStorage
        .connect(user10)
        .acceptDealTokens(user10ProRataAvail);

      expect(await aelinDealProxyStorage.balanceOf(user10.address)).to.equal(
        user10ProRataAvail
          .mul(10 ** (dealTokenDecimals - usdcDecimals))
          .mul(feesNumerator)
          .div(base)
      );

      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(
        user7ProRataAvail
          .add(user6ProRataAvail)
          .add(user9ProRataAvail)
          .add(user10ProRataAvail)
      );

      const acceptLogs = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.AcceptDeal()
      );
      expect(acceptLogs.length).to.equal(4);

      const mintLogs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.Transfer(nullAddress)
      );

      expect(mintLogs.length).to.equal(4 * 3);

      const totalToHolderFromEvents = acceptLogs.reduce(
        (acc, log) => acc.add(log.args.poolTokenAmount),
        ethers.BigNumber.from(0)
      );
      expect(await usdcContract.balanceOf(aaveWhaleTwo.address)).to.equal(
        totalToHolderFromEvents
      );

      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      expect(await aelinPoolProxyStorage.balanceOf(user6.address)).to.not.equal(
        0
      );
      await aelinPoolProxyStorage.connect(user6).acceptMaxDealTokens();

      expect(await aelinPoolProxyStorage.balanceOf(user6.address)).to.equal(0);

      await ethers.provider.send("evm_increaseTime", [
        openRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);
      // hmm should do a cehck on balance before and after withdrawExpiry here
      await aelinDealProxyStorage.connect(aaveWhaleTwo).withdrawExpiry();

      const [, withdrawUnderlyingLog] = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.WithdrawUnderlyingDealTokens()
      );
      expect(withdrawUnderlyingLog.args.depositor).to.equal(
        aaveWhaleTwo.address
      );
      expect(
        withdrawUnderlyingLog.args.underlyingDealTokenAddress.toLowerCase()
      ).to.equal(aaveContract.address.toLowerCase());
      expect(withdrawUnderlyingLog.address).to.equal(
        aelinDealProxyStorage.address
      );
      // the entire amount has been taken
      expect(withdrawUnderlyingLog.args.underlyingDealTokenAmount).to.equal(0);

      await ethers.provider.send("evm_increaseTime", [
        vestingCliff + vestingPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      expect(await aaveContract.balanceOf(user6.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user7.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user8.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user9.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user10.address)).to.equal(0);

      await aelinDealProxyStorage.connect(user6).claim();
      await aelinDealProxyStorage.connect(user7).claim();
      await aelinDealProxyStorage.connect(user9).claim();
      await aelinDealProxyStorage.connect(user10).claim();

      const logs = await aelinDealProxyStorage.queryFilter(
        aelinDealProxyStorage.filters.ClaimedUnderlyingDealTokens()
      );

      // TODO calculate exact claim amount
      expect(await aaveContract.balanceOf(user6.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user7.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user8.address)).to.equal(0);
      expect(await aaveContract.balanceOf(user9.address)).to.not.equal(0);
      expect(await aaveContract.balanceOf(user10.address)).to.not.equal(0);

      expect(await aaveContract.balanceOf(user6.address)).to.equal(
        logs[0].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user7.address)).to.equal(
        logs[1].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user9.address)).to.equal(
        logs[2].args.underlyingDealTokensClaimed
      );
      expect(await aaveContract.balanceOf(user10.address)).to.equal(
        logs[3].args.underlyingDealTokensClaimed
      );
    });
  });

  describe("transfer blocked in redeem window", function () {
    beforeEach(async function () {
      const aelinPoolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact,
        [
          aelinPoolLogic.address,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
        ]
      )) as AelinPoolFactory;

      await aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseAmount,
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry
        );

      const [createPoolLog] = await aelinPoolFactory.queryFilter(
        aelinPoolFactory.filters.CreatePool()
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
          aaveWhaleOne.address,
          holderFundingExpiry
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
        purchaseAmount
      );
      await aelinPoolProxyStorage
        .connect(user1)
        .transfer(user2.address, purchaseAmount);
      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(0);
      expect(await aelinPoolProxyStorage.balanceOf(user2.address)).to.equal(
        purchaseAmount
      );
    });

    it("should block a transfer during the redeem window", async function () {
      await aaveContract
        .connect(aaveWhaleOne)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhaleOne)
        .depositUnderlying(underlyingDealTokenTotal);

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        purchaseAmount
      );
      await expect(
        aelinPoolProxyStorage
          .connect(user1)
          .transfer(user2.address, purchaseAmount)
      ).to.be.revertedWith("no transfers after redeem starts");
    });

    it("should block a transferFrom during the redeem window", async function () {
      await aaveContract
        .connect(aaveWhaleOne)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhaleOne)
        .depositUnderlying(underlyingDealTokenTotal);

      expect(await aelinPoolProxyStorage.balanceOf(user1.address)).to.equal(
        purchaseAmount
      );
      await expect(
        aelinPoolProxyStorage
          .connect(user1)
          .transferFrom(user1.address, user2.address, purchaseAmount)
      ).to.be.revertedWith("no transfers after redeem starts");
    });
  });

  describe("accept deal tests", function () {
    beforeEach(async function () {
      const aelinPoolFactory = (await deployContract(
        deployer,
        AelinPoolFactoryArtifact,
        [
          aelinPoolLogic.address,
          aelinDealLogic.address,
          mockAelinRewardsAddress,
        ]
      )) as AelinPoolFactory;

      await aelinPoolFactory
        .connect(sponsor)
        .createPool(
          name,
          symbol,
          purchaseAmount.mul(4),
          usdcContract.address,
          duration,
          sponsorFee,
          purchaseExpiry
        );

      const [createPoolLog] = await aelinPoolFactory.queryFilter(
        aelinPoolFactory.filters.CreatePool()
      );

      aelinPoolProxyStorage = (await ethers.getContractAt(
        AelinPoolArtifact.abi,
        createPoolLog.args.poolAddress
      )) as AelinPool;

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user11)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);

      // purchasers get approval to buy pool tokens
      await usdcContract
        .connect(user12)
        .approve(aelinPoolProxyStorage.address, purchaseAmount);

      // purchasers buy pool tokens
      await aelinPoolProxyStorage
        .connect(user11)
        .purchasePoolTokens(purchaseAmount);

      await aelinPoolProxyStorage
        .connect(user12)
        .purchasePoolTokens(purchaseAmount);

      await ethers.provider.send("evm_increaseTime", [purchaseExpiry + 1]);
      await ethers.provider.send("evm_mine", []);

      await aelinPoolProxyStorage
        .connect(sponsor)
        .createDeal(
          aaveContract.address,
          purchaseAmount,
          underlyingDealTokenTotal,
          vestingPeriod,
          vestingCliff,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          aaveWhaleOne.address,
          holderFundingExpiry
        );

      const [createDealLog] = await aelinPoolProxyStorage.queryFilter(
        aelinPoolProxyStorage.filters.CreateDeal()
      );

      aelinDealProxyStorage = (await ethers.getContractAt(
        AelinDealArtifact.abi,
        createDealLog.args.dealContract
      )) as AelinDeal;

      await aaveContract
        .connect(aaveWhaleOne)
        .approve(aelinDealProxyStorage.address, underlyingDealTokenTotal);

      await aelinDealProxyStorage
        .connect(aaveWhaleOne)
        .depositUnderlying(underlyingDealTokenTotal);
    });

    it("should accept max deal tokens", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(0);
      await aelinPoolProxyStorage.connect(user11).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount.div(2).mul(feesNumerator).div(base)
      );
    });

    it("should accept partial deal tokens", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user12.address)).to.equal(0);
      await aelinPoolProxyStorage
        .connect(user12)
        .acceptDealTokens(purchaseAmount.div(4));
      expect(await aelinDealProxyStorage.balanceOf(user12.address)).to.equal(
        dealTokenAmount.div(4).mul(feesNumerator).div(base)
      );
    });

    it("should revert outside of redeem window", async function () {
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + openRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);
      await expect(
        aelinPoolProxyStorage
          .connect(user12)
          .acceptDealTokens(purchaseAmount.div(4))
      ).to.be.revertedWith("outside of redeem window");
    });

    it("should revert with accepting more than share", async function () {
      await expect(
        aelinPoolProxyStorage
          .connect(user12)
          .acceptDealTokens(purchaseAmount.mul(2))
      ).to.be.revertedWith("accepting more than share");
    });

    it("should work in open redemption period with max accept", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(0);
      await aelinPoolProxyStorage.connect(user11).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount.div(2).mul(feesNumerator).div(base)
      );
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      await aelinPoolProxyStorage.connect(user11).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount.mul(feesNumerator).div(base)
      );
    });

    it("should work in open redemption period with partial accept", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(0);
      await aelinPoolProxyStorage.connect(user11).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount.div(2).mul(feesNumerator).div(base)
      );
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      const partialPurchaseAmount = ethers.utils.parseUnits(
        "0.0001",
        usdcDecimals
      );
      const partialDealAmount = ethers.utils.parseUnits(
        "0.0001",
        dealTokenDecimals
      );
      await aelinPoolProxyStorage
        .connect(user11)
        .acceptDealTokens(partialPurchaseAmount);

      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount
          .div(2)
          .add(partialDealAmount)
          .mul(feesNumerator)
          .div(base)
      );
    });

    it("should revert with ineligible in open period due to not maxxing pro rata", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user12.address)).to.equal(0);
      await aelinPoolProxyStorage
        .connect(user12)
        .acceptDealTokens(purchaseAmount.div(4));
      expect(await aelinDealProxyStorage.balanceOf(user12.address)).to.equal(
        dealTokenAmount.div(4).mul(feesNumerator).div(base)
      );
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      await expect(
        aelinPoolProxyStorage.connect(user12).acceptMaxDealTokens()
      ).to.be.revertedWith("ineligible: didn't max pro rata");
    });

    it("should revert with accepting more than share in open period", async function () {
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(0);
      await aelinPoolProxyStorage.connect(user11).acceptMaxDealTokens();
      expect(await aelinDealProxyStorage.balanceOf(user11.address)).to.equal(
        dealTokenAmount.div(2).mul(feesNumerator).div(base)
      );
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + 1,
      ]);
      const excessAmount = ethers.utils.parseUnits("500000000", usdcDecimals);
      await expect(
        aelinPoolProxyStorage.connect(user11).acceptDealTokens(excessAmount)
      ).to.be.revertedWith("accepting more than share");
    });
  });
});
