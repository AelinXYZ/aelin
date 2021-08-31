import chai, { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import { AelinPool, AelinDeal, AelinPoolFactory, ERC20 } from "../../typechain";

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

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;
  const usdcDecimals = 8;

  const aaveContractAddress = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9";
  let aaveContract: ERC20;
  const aaveDecimals = 18;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  const uniswapWhaleAddress = "0x47173b170c64d16393a52e6c480b3ad8c302ba1e";
  let uniswapWhaleSigner: SignerWithAddress;

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

    usdcWhaleSigner = await getImpersonatedSigner(usdcWhaleAddress);
    uniswapWhaleSigner = await getImpersonatedSigner(uniswapWhaleAddress);
    const AelinDeal = await ethers.getContractFactory("AelinDeal");
    aelinDeal = (await AelinDeal.deploy()) as AelinDeal;
    const AelinPool = await ethers.getContractFactory("AelinPool");
    aelinPool = (await AelinPool.deploy()) as AelinPool;
    const AelinPoolFactory = await ethers.getContractFactory(
      "AelinPoolFactory"
    );
    aelinPoolFactory = (await AelinPoolFactory.deploy()) as AelinPoolFactory;
    // TODO delete this once we have a fork of mainnet running a deployed version of
    // the pool and deal logic contracts
    aelinPool.setAelinDealAddress(aelinDeal.address);
    aelinPoolFactory.setAelinPoolAddress(aelinPool.address);

    await fundUsdcToUsers([user1, user2, user3, user4, user5]);
  });

  const name = "Pool name";
  const symbol = "POOL";
  const purchaseTokenCap = ethers.utils.parseUnits("175", usdcDecimals);
  const duration = 365 * 24 * 60 * 60; // one year
  const sponsorFee = 3000; // 0 to 98000 represents 0 to 98%
  const purchaseExpiry = 30 * 24 * 60 * 60; // one month
  address _underlying_deal_token,
  uint _deal_purchase_token_total,
  uint _underlying_deal_token_total,
  uint _vesting_period,
  uint _vesting_cliff,
  uint _redemption_period,
  address _holder

  it(`creates a capped pool, gets fully funded by purchasers, the deal is created and then funded,
  half the pool accepts, the deal expires, the tokens fully vest and are claimed`, async () => {
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

    await aelinPool
      .connect(user1)
      .purchasePoolTokens(ethers.utils.parseUnits("50", usdcDecimals));
    await aelinPool
      .connect(user2)
      .purchasePoolTokens(ethers.utils.parseUnits("50", usdcDecimals));
    await aelinPool
      .connect(user3)
      .purchasePoolTokens(ethers.utils.parseUnits("50", usdcDecimals));
    await aelinPool
      .connect(user4)
      .purchasePoolTokens(ethers.utils.parseUnits("50", usdcDecimals));
    await aelinPool
      .connect(user5)
      .purchasePoolTokens(ethers.utils.parseUnits("50", usdcDecimals));

    await aelinPool.connect(sponsor).createDeal(

      usdcWhaleSigner.address
    );
  });
});
