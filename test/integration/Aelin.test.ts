import chai, { expect } from "chai";
import { ethers, network, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { solidity } from "ethereum-waffle";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import AelinPoolArtifact from "../../artifacts/contracts/AelinPool.sol/AelinPool.json";
import AelinPoolFactoryArtifact from "../../artifacts/contracts/AelinPoolFactory.sol/AelinPoolFactory.json";
import { AelinPool, AelinDeal, AelinPoolFactory, ERC20 } from "../../typechain";

const { deployContract } = waffle;

chai.use(solidity);

describe.only("integration test", () => {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;
  let user5: SignerWithAddress;
  let aelinPool: AelinPool;
  let aelinPoolFactory: AelinPoolFactory;
  let aelinDeal: AelinDeal;
  const dealOrPoolTokenDecimals = 18;

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;
  const usdcDecimals = 8;

  const aaveContractAddress = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9";
  let aaveContract: ERC20;
  const aaveDecimals = 18;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  // AAVE DAO is the holder
  const aaveDAOAddress = "0xc697051d1c6296c24ae3bcef39aca743861d9a81";
  let aaveDAO: SignerWithAddress;

  const fundUsdcToUsers = async (users: SignerWithAddress[]) => {
    const amount = ethers.utils.parseUnits("50000000", usdcDecimals);

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

    usdcWhaleSigner = await getImpersonatedSigner(usdcWhaleAddress);
    aaveDAO = await getImpersonatedSigner(aaveDAOAddress);
    aelinDeal = (await deployContract(
      deployer,
      AelinDealArtifact
    )) as AelinDeal;
    aelinPool = (await deployContract(
      deployer,
      AelinPoolArtifact
    )) as AelinPool;
    aelinPoolFactory = (await deployContract(
      deployer,
      AelinPoolFactoryArtifact
    )) as AelinPoolFactory;
    // TODO delete these setters once we have a fork of mainnet running a deployed version of
    // the pool and deal logic contracts where we can hardcode the right addresses
    aelinPool.setAelinDealAddress(aelinDeal.address);
    aelinPoolFactory.setAelinPoolAddress(aelinPool.address);

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
    // capped pool is created
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

    // purchasers buy pool tokens
    await aelinPool
      .connect(user1)
      .purchasePoolTokens(ethers.utils.parseUnits("5000", usdcDecimals));
    await aelinPool
      .connect(user2)
      .purchasePoolTokens(ethers.utils.parseUnits("5000", usdcDecimals));
    await aelinPool
      .connect(user3)
      .purchasePoolTokens(ethers.utils.parseUnits("5000", usdcDecimals));
    // user 4 only gets 2500 at the end
    await aelinPool
      .connect(user4)
      .purchasePoolTokens(ethers.utils.parseUnits("5000", usdcDecimals));

    await aelinPool
      .connect(user4)
      .withdrawFromPool(
        ethers.utils.parseUnits("500", dealOrPoolTokenDecimals)
      );
    await aelinPool.connect(user4).withdrawMaxFromPool();

    await aelinPool
      .connect(sponsor)
      .createDeal(
        aaveContract.address,
        dealPurchaseTokenTotal,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        redemptionPeriod,
        aaveDAO.address
      );

    // deposits double by mistake
    await aelinDeal
      .connect(aaveDAO)
      .depositUnderlying(underlyingDealTokenTotal.mul(2));

    // withdraws the extra amount
    await aelinDeal.connect(aaveDAO).withdraw();

    expect(await usdcContract.balanceOf(aaveDAO.address)).to.equal(0);

    // 5000 + 5000 + 2500 + 100 = 12600 USDC will be available to the holder
    await aelinPool.connect(user1.address).acceptMaxDealTokens();
    await aelinPool
      .connect(user2.address)
      .acceptMaxDealTokensAndAllocate(user1.address);
    await aelinPool
      .connect(user3.address)
      .acceptDealTokensAndAllocate(
        user4.address,
        ethers.utils.parseUnits("2500", dealOrPoolTokenDecimals)
      );
    await aelinPool
      .connect(user4.address)
      .acceptDealTokens(
        ethers.utils.parseUnits("100", dealOrPoolTokenDecimals)
      );

    await ethers.provider.send("evm_increaseTime", [redemptionPeriod + 1]);
    await ethers.provider.send("evm_mine", []);

    await aelinDeal.connect(aaveDAO).withdrawExpiry();

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
    await aelinDeal.connect(user2).claim(user2.address);
    await aelinDeal.connect(user5).claim(user3.address);
    await aelinDeal.connect(user4).claim(user4.address);

    const [log1, log2, log3, log4] = await aelinDeal.queryFilter(
      aelinDeal.filters.ClaimedUnderlyingDealTokens()
    );

    expect(await aaveContract.balanceOf(user1.address)).to.equal(0);
    expect(await aaveContract.balanceOf(user2.address)).to.equal(
      log2.args.underlyingDealTokensClaimed
    );
    expect(await aaveContract.balanceOf(user3.address)).to.equal(
      log3.args.underlyingDealTokensClaimed
    );
    expect(await aaveContract.balanceOf(user4.address)).to.equal(
      log4.args.underlyingDealTokensClaimed
    );
    expect(await aaveContract.balanceOf(user5.address)).to.equal(
      log1.args.underlyingDealTokensClaimed
    );
    expect(await usdcContract.balanceOf(aaveDAO.address)).to.equal(
      ethers.utils.parseUnits("126000", usdcDecimals)
    );
  });
});
