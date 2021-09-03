import chai, { expect } from "chai";
import { ethers, network, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { solidity } from "ethereum-waffle";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import FixedCompileAelinDealArtifact from "../../FixedCompileAelinDeal.sol/AelinDeal.json";
import FixedCompileAelinPoolArtifact from "../../FixedCompileAelinPool.sol/AelinPool.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";
import Create2FactoryArtifact from "../../artifacts/contracts/Create2Factory.sol/Create2Factory.json";
import { salt } from "../../scripts/constants";

import {
  AelinPool,
  AelinDeal,
  AelinPoolFactory,
  ERC20,
  Create2Factory,
} from "../../typechain";

const { deployContract } = waffle;

chai.use(solidity);

describe.skip("integration test", () => {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;
  let user5: SignerWithAddress;
  let aelinPool: AelinPool;
  let aelinDeal: AelinDeal;
  let aelinPoolFactory: AelinPoolFactory;
  let create2Factory: Create2Factory;
  const dealOrPoolTokenDecimals = 18;

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;
  const usdcDecimals = 8;

  const aaveContractAddress = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9";
  let aaveContract: ERC20;
  const aaveDecimals = 18;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  const aaveWhaleAddress = "0x73f9B272aBda7A97CB1b237D85F9a7236EDB6F16";
  let aaveWhale: SignerWithAddress;

  const fundUsdcToUsers = async (users: SignerWithAddress[]) => {
    const amount = ethers.utils.parseUnits("100000", usdcDecimals);

    users.forEach((user) => {
      usdcContract.connect(usdcWhaleSigner).transfer(user.address, amount);
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

    create2Factory = (await ethers.getContractAt(
      Create2FactoryArtifact.abi,
      process.env.CREATE2 as string
    )) as Create2Factory;

    usdcWhaleSigner = await getImpersonatedSigner(usdcWhaleAddress);
    aaveWhale = await getImpersonatedSigner(aaveWhaleAddress);

    // NOTE that the deploy method for aelin pool exceeds the default hardhat 3M gas limit
    // and aelin deal is close to the limit
    await ethers.provider.send("evm_setBlockGasLimit", [
      `0x${ethers.BigNumber.from(6000000)}`,
    ]);
    await ethers.provider.send("evm_mine", []);

    // NOTE the output of these deployments are deterministic and already hardcoded into
    // the contracts as addresses for the underlying deal and pool logic
    await create2Factory.deploy(FixedCompileAelinDealArtifact.bytecode, salt);
    const dealDeployedLogs = await create2Factory.queryFilter(
      create2Factory.filters.Deployed()
    );
    console.log(
      "deterministic deal address:",
      dealDeployedLogs[dealDeployedLogs.length - 1].args.addr
    );
    await create2Factory.deploy(FixedCompileAelinPoolArtifact.bytecode, salt);
    const poolDeployedLogs = await create2Factory.queryFilter(
      create2Factory.filters.Deployed()
    );
    console.log(
      "deterministic pool address:",
      poolDeployedLogs[poolDeployedLogs.length - 1].args.addr
    );

    aelinPoolFactory = (await deployContract(
      deployer,
      AelinPoolFactoryArtifact
    )) as AelinPoolFactory;

    await fundUsdcToUsers([user1, user2, user3, user4, user5]);
  });

  const oneYear = 365 * 24 * 60 * 60; // one year
  const name = "Pool name";
  const symbol = "POOL";
  const purchaseTokenCap = ethers.utils.parseUnits("17500", usdcDecimals);
  const duration = oneYear;
  const sponsorFee = 3000; // 0 to 98000 represents 0 to 98%
  const purchaseExpiry = 30 * 24 * 60 * 60; // one month

  const dealPurchaseTokenTotal = ethers.utils.parseUnits("15000", usdcDecimals);
  // one AAVE is $300
  const underlyingDealTokenTotal = ethers.utils.parseUnits("50", aaveDecimals);
  const vestingPeriod = oneYear;
  const vestingCliff = oneYear;
  const redemptionPeriod = 7 * 24 * 60 * 60;

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
        purchaseExpiry
      );

    const [createPoolLog] = await aelinPoolFactory.queryFilter(
      aelinPoolFactory.filters.CreatePool()
    );

    // partial check of logs. already testing all logs in unit tests
    expect(createPoolLog.args.poolAddress).to.be.properAddress;
    expect(createPoolLog.args.name).to.equal("aePool-" + name);

    aelinPool = (await ethers.getContractAt(
      FixedCompileAelinPoolArtifact.abi,
      createPoolLog.args.poolAddress
    )) as AelinPool;

    const purchaseAmount = ethers.utils.parseUnits("5000", usdcDecimals);
    // purchasers get approval to buy pool tokens
    await usdcContract
      .connect(user1)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user2)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user3)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user4)
      .approve(aelinPool.address, purchaseAmount);

    // purchasers buy pool tokens
    await aelinPool.connect(user1).purchasePoolTokens(purchaseAmount);
    await aelinPool.connect(user2).purchasePoolTokens(purchaseAmount);
    await aelinPool.connect(user3).purchasePoolTokens(purchaseAmount);
    // user 4 only gets 2500 at the end
    await aelinPool.connect(user4).purchasePoolTokens(purchaseAmount);

    await aelinPool
      .connect(sponsor)
      .createDeal(
        aaveContract.address,
        dealPurchaseTokenTotal,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        redemptionPeriod,
        aaveWhale.address
      );

    const [createDealLog] = await aelinPool.queryFilter(
      aelinPool.filters.CreateDeal()
    );

    expect(createDealLog.args.dealContract).to.be.properAddress;
    expect(createDealLog.args.name).to.equal("aeDeal-" + name);

    aelinDeal = (await ethers.getContractAt(
      FixedCompileAelinDealArtifact.abi,
      createDealLog.args.dealContract
    )) as AelinDeal;

    await aelinPool
      .connect(user4)
      .withdrawFromPool(
        ethers.utils.parseUnits("500", dealOrPoolTokenDecimals)
      );
    await aelinPool.connect(user4).withdrawMaxFromPool();

    await aaveContract
      .connect(aaveWhale)
      .approve(aelinDeal.address, underlyingDealTokenTotal.add(1));

    await aelinDeal
      .connect(aaveWhale)
      .depositUnderlying(underlyingDealTokenTotal.add(1));

    // withdraws the extra 1
    await aelinDeal.connect(aaveWhale).withdraw();

    expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(0);

    // 5000 + 5000 + 2500 + 100 = 12600 USDC will be available to the holder
    await aelinPool.connect(user1).acceptMaxDealTokens();
    await aelinPool
      .connect(user2)
      .acceptMaxDealTokensAndAllocate(user1.address);

    const user3ProRataBalance = await aelinPool.proRataBalance(user3.address);
    const user4ProRataBalance = await aelinPool.proRataBalance(user4.address);
    await aelinPool
      .connect(user3)
      .acceptDealTokensAndAllocate(user4.address, user3ProRataBalance);

    await aelinPool.connect(user4).acceptDealTokens(user4ProRataBalance);
    const acceptLogs = await aelinPool.queryFilter(
      aelinPool.filters.AcceptDeal()
    );
    expect(acceptLogs.length).to.equal(4);

    const mintLogs = await aelinDeal.queryFilter(
      aelinDeal.filters.MintDealTokens()
    );
    const totalToHolder = acceptLogs.reduce(
      (acc, log) => acc.add(log.args.underlyingToHolderAmt),
      ethers.BigNumber.from(0)
    );
    expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
      totalToHolder
    );
    expect(mintLogs.length).to.equal(4 * 3);

    await ethers.provider.send("evm_increaseTime", [redemptionPeriod + 1]);
    await ethers.provider.send("evm_mine", []);

    await aelinDeal.connect(aaveWhale).withdrawExpiry();

    await ethers.provider.send("evm_increaseTime", [
      vestingCliff + vestingPeriod + 1,
    ]);
    await ethers.provider.send("evm_mine", []);

    expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user4.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user5.address)).to.equal(0);

    await aelinDeal
      .connect(user1)
      .claimAndAllocate(user1.address, user5.address);
    await aelinDeal.connect(user5).claim(user4.address);

    const logs = await aelinDeal.queryFilter(
      aelinDeal.filters.ClaimedUnderlyingDealTokens()
    );

    expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user4.address)).to.not.equal(0);
    expect(await aaveContract.balanceOf(user5.address)).to.not.equal(0);

    expect(await aaveContract.balanceOf(user5.address)).to.equal(
      logs[0].args.underlyingDealTokensClaimed
    );
    expect(await aaveContract.balanceOf(user4.address)).to.equal(
      logs[1].args.underlyingDealTokensClaimed
    );
  });

  it(`
    1. creates an uncapped pool
    2. gets funded with $100M by purchasers
    3. the deal is created for $50M
    4. $30M of the pool accepts during the proRata period
    5. the remaining $20M is taken in the open period before deal expires
    5. the holder withdraws unaccepted tokens
    6. the tokens fully vest and are claimed
  `, async () => {
    const uncappedPool = 0;
    await aelinPoolFactory
      .connect(sponsor)
      .createPool(
        name,
        symbol,
        uncappedPool,
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

    aelinPool = (await ethers.getContractAt(
      FixedCompileAelinPoolArtifact.abi,
      createPoolLog.args.poolAddress
    )) as AelinPool;

    const purchaseAmount = ethers.utils.parseUnits("5000", usdcDecimals);
    // purchasers get approval to buy pool tokens
    await usdcContract
      .connect(user1)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user2)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user3)
      .approve(aelinPool.address, purchaseAmount);
    await usdcContract
      .connect(user4)
      .approve(aelinPool.address, purchaseAmount);

    // purchasers buy pool tokens
    await aelinPool.connect(user1).purchasePoolTokens(purchaseAmount);
    await aelinPool.connect(user2).purchasePoolTokens(purchaseAmount);
    await aelinPool.connect(user3).purchasePoolTokens(purchaseAmount);
    // user 4 only gets 2500 at the end
    await aelinPool.connect(user4).purchasePoolTokens(purchaseAmount);

    await aelinPool
      .connect(sponsor)
      .createDeal(
        aaveContract.address,
        dealPurchaseTokenTotal,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        redemptionPeriod,
        aaveWhale.address
      );

    const [createDealLog] = await aelinPool.queryFilter(
      aelinPool.filters.CreateDeal()
    );

    expect(createDealLog.args.dealContract).to.be.properAddress;
    expect(createDealLog.args.name).to.equal("aeDeal-" + name);

    aelinDeal = (await ethers.getContractAt(
      FixedCompileAelinDealArtifact.abi,
      createDealLog.args.dealContract
    )) as AelinDeal;

    await aelinPool
      .connect(user4)
      .withdrawFromPool(
        ethers.utils.parseUnits("500", dealOrPoolTokenDecimals)
      );
    await aelinPool.connect(user4).withdrawMaxFromPool();

    await aaveContract
      .connect(aaveWhale)
      .approve(aelinDeal.address, underlyingDealTokenTotal.add(1));

    await aelinDeal
      .connect(aaveWhale)
      .depositUnderlying(underlyingDealTokenTotal.add(1));

    // withdraws the extra 1
    await aelinDeal.connect(aaveWhale).withdraw();

    expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(0);

    // 5000 + 5000 + 2500 + 100 = 12600 USDC will be available to the holder
    await aelinPool.connect(user1).acceptMaxDealTokens();
    await aelinPool
      .connect(user2)
      .acceptMaxDealTokensAndAllocate(user1.address);

    const user3ProRataBalance = await aelinPool.proRataBalance(user3.address);
    const user4ProRataBalance = await aelinPool.proRataBalance(user4.address);
    await aelinPool
      .connect(user3)
      .acceptDealTokensAndAllocate(user4.address, user3ProRataBalance);

    await aelinPool.connect(user4).acceptDealTokens(user4ProRataBalance);
    const acceptLogs = await aelinPool.queryFilter(
      aelinPool.filters.AcceptDeal()
    );
    expect(acceptLogs.length).to.equal(4);

    const mintLogs = await aelinDeal.queryFilter(
      aelinDeal.filters.MintDealTokens()
    );
    const totalToHolder = acceptLogs.reduce(
      (acc, log) => acc.add(log.args.underlyingToHolderAmt),
      ethers.BigNumber.from(0)
    );
    expect(await usdcContract.balanceOf(aaveWhale.address)).to.equal(
      totalToHolder
    );
    expect(mintLogs.length).to.equal(4 * 3);

    await ethers.provider.send("evm_increaseTime", [redemptionPeriod + 1]);
    await ethers.provider.send("evm_mine", []);

    await aelinDeal.connect(aaveWhale).withdrawExpiry();

    await ethers.provider.send("evm_increaseTime", [
      vestingCliff + vestingPeriod + 1,
    ]);
    await ethers.provider.send("evm_mine", []);

    expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user4.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user5.address)).to.equal(0);

    await aelinDeal
      .connect(user1)
      .claimAndAllocate(user1.address, user5.address);
    await aelinDeal.connect(user5).claim(user4.address);

    const logs = await aelinDeal.queryFilter(
      aelinDeal.filters.ClaimedUnderlyingDealTokens()
    );

    expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user2.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user3.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user4.address)).to.not.equal(0);
    expect(await aaveContract.balanceOf(user5.address)).to.not.equal(0);

    expect(await aaveContract.balanceOf(user5.address)).to.equal(
      logs[0].args.underlyingDealTokensClaimed
    );
    expect(await aaveContract.balanceOf(user4.address)).to.equal(
      logs[1].args.underlyingDealTokensClaimed
    );
  });
});
