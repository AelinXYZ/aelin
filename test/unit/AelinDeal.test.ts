import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { MockContract, solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import AelinDealArtifact from "../../artifacts/contracts/AelinDeal.sol/AelinDeal.json";
import { AelinDeal } from "../../typechain";

const { deployContract, deployMockContract } = waffle;

chai.use(solidity);

describe("AelinDeal", function () {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let holder: SignerWithAddress;
  let purchaser: SignerWithAddress;
  let aelinDeal: AelinDeal;
  let purchaseToken: MockContract;
  let underlyingDealToken: MockContract;

  const purchaseTokenDecimals = 6;
  const underlyingDealTokenDecimals = 8;
  const poolTokenDecimals = 18;
  const oneDay = 24 * 60 * 60;
  const oneYear = oneDay * 365;
  const oneWeek = oneDay * 7;
  const name = "TestName";
  const symbol = "TestSymbol";
  const underlyingBaseAmount = 100;
  const underlyingDealTokenTotal = ethers.utils.parseUnits(
    underlyingBaseAmount.toString(),
    underlyingDealTokenDecimals
  );
  const purchaseBaseAmount = 50;
  const purchaseTokenTotalForDeal = ethers.utils.parseUnits(
    purchaseBaseAmount.toString(),
    purchaseTokenDecimals
  );

  const vestingPeriod = oneYear;
  const vestingCliff = oneYear;
  const proRataRedemptionPeriod = oneWeek;
  const openRedemptionPeriod = oneDay;
  const redmeptionPeriod = proRataRedemptionPeriod + openRedemptionPeriod;
  const redemptionEnd =
    vestingCliff +
    vestingPeriod +
    proRataRedemptionPeriod +
    openRedemptionPeriod;
  // same logic as the convertUnderlyingToAelinAmount method
  const poolTokenMaxPurchaseAmount = purchaseTokenTotalForDeal.mul(
    Math.pow(10, poolTokenDecimals - purchaseTokenDecimals)
  );

  const underlyingPerPoolExchangeRate = (
    ((underlyingBaseAmount * Math.pow(10, 8)) /
      (purchaseBaseAmount * Math.pow(10, poolTokenDecimals))) *
    Math.pow(10, poolTokenDecimals)
  ).toString();

  const nullAddress = "0x0000000000000000000000000000000000000000";
  const mintAmountBase = 2;
  const mintAmount = ethers.utils.parseUnits(
    mintAmountBase.toString(),
    poolTokenDecimals
  );
  const underlyingRemovedBalance =
    Number(underlyingPerPoolExchangeRate) * mintAmountBase;
  const remainingBalance = underlyingDealTokenTotal.sub(
    underlyingRemovedBalance
  );
  const expectedClaimUnderlying = underlyingRemovedBalance;

  before(async () => {
    [deployer, sponsor, holder, purchaser] = await ethers.getSigners();
    purchaseToken = await deployMockContract(deployer, ERC20Artifact.abi);
    underlyingDealToken = await deployMockContract(deployer, ERC20Artifact.abi);
    await purchaseToken.mock.decimals.returns(purchaseTokenDecimals);
    await underlyingDealToken.mock.decimals.returns(
      underlyingDealTokenDecimals
    );
  });

  beforeEach(async () => {
    aelinDeal = (await deployContract(sponsor, AelinDealArtifact)) as AelinDeal;
  });

  const successfullyInitializeDeal = () =>
    aelinDeal
      .connect(deployer)
      .initialize(
        name,
        symbol,
        underlyingDealToken.address,
        underlyingDealTokenTotal,
        vestingPeriod,
        vestingCliff,
        proRataRedemptionPeriod,
        openRedemptionPeriod,
        holder.address,
        poolTokenMaxPurchaseAmount
      );

  const fundDealAndMintTokens = async () => {
    await underlyingDealToken.mock.balanceOf
      .withArgs(holder.address)
      .returns(underlyingDealTokenTotal);

    await underlyingDealToken.mock.transferFrom
      .withArgs(holder.address, aelinDeal.address, underlyingDealTokenTotal)
      .returns(true);

    await underlyingDealToken.mock.balanceOf
      .withArgs(aelinDeal.address)
      .returns(underlyingDealTokenTotal);

    await aelinDeal.connect(holder).depositUnderlying(underlyingDealTokenTotal);

    await aelinDeal.connect(deployer).mint(purchaser.address, mintAmount);
  };

  describe("initialize", function () {
    it("should successfully initialize", async function () {
      const tx = await successfullyInitializeDeal();

      // TODO test the aelinDeal.AELIN_POOL() variable
      expect(await aelinDeal.name()).to.equal(`aeDeal-${name}`);
      expect(await aelinDeal.symbol()).to.equal(`aeD-${symbol}`);
      expect(await aelinDeal.holder()).to.equal(holder.address);
      expect(await aelinDeal.underlyingDealToken()).to.equal(
        underlyingDealToken.address
      );
      expect(await aelinDeal.aelinPool()).to.equal(deployer.address);
      expect(await aelinDeal.underlyingDealTokenDecimals()).to.equal(
        underlyingDealTokenDecimals
      );
      const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);
      expect(await aelinDeal.underlyingDealTokenTotal()).to.equal(
        underlyingDealTokenTotal.toString()
      );
      const actualVestingCliff =
        timestamp +
        proRataRedemptionPeriod +
        openRedemptionPeriod +
        vestingCliff;
      expect(await aelinDeal.vestingCliff()).to.equal(actualVestingCliff);
      expect(await aelinDeal.vestingPeriod()).to.equal(vestingPeriod);
      expect(await aelinDeal.vestingExpiry()).to.equal(
        actualVestingCliff + vestingPeriod
      );
      expect(await aelinDeal.proRataRedemptionPeriod()).to.equal(
        proRataRedemptionPeriod
      );
      expect(await aelinDeal.openRedemptionPeriod()).to.equal(
        openRedemptionPeriod
      );
      expect(await aelinDeal.underlyingPerPoolExchangeRate()).to.equal(
        underlyingPerPoolExchangeRate
      );
    });

    it("should only allow initialization once", async function () {
      await successfullyInitializeDeal();
      await expect(successfullyInitializeDeal()).to.be.revertedWith(
        "can only initialize once"
      );
    });
  });

  describe("tests needing initialize deal", function () {
    beforeEach(async () => {
      await successfullyInitializeDeal();
    });

    describe("depositUnderlying", function () {
      beforeEach(async () => {
        await underlyingDealToken.mock.balanceOf
          .withArgs(holder.address)
          .returns(underlyingDealTokenTotal);

        await underlyingDealToken.mock.transferFrom
          .withArgs(holder.address, aelinDeal.address, underlyingDealTokenTotal)
          .returns(true);

        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(underlyingDealTokenTotal);
      });

      it("should complete the deposit when the total amount has been reached", async function () {
        expect(await aelinDeal.depositComplete()).to.equal(false);

        const tx = await aelinDeal
          .connect(holder)
          .depositUnderlying(underlyingDealTokenTotal);

        expect(await aelinDeal.depositComplete()).to.equal(true);

        const { timestamp } = await ethers.provider.getBlock(tx.blockHash!);

        const [depositDealTokensLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.DepositDealTokens()
        );
        const [dealFundedLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.DealFullyFunded()
        );
        expect(depositDealTokensLog.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(depositDealTokensLog.args.depositor).to.equal(holder.address);
        expect(depositDealTokensLog.args.dealContract).to.equal(
          aelinDeal.address
        );
        expect(depositDealTokensLog.args.underlyingDealTokenAmount).to.equal(
          underlyingDealTokenTotal
        );

        expect(dealFundedLog.args.dealAddress).to.equal(aelinDeal.address);
        expect(dealFundedLog.args.poolAddress).to.be.properAddress;
        expect(dealFundedLog.args.proRataRedemptionStart).to.equal(timestamp);
        expect(dealFundedLog.args.proRataRedemptionExpiry).to.equal(
          timestamp + proRataRedemptionPeriod
        );
        expect(dealFundedLog.args.openRedemptionStart).to.equal(
          timestamp + proRataRedemptionPeriod
        );
        expect(dealFundedLog.args.openRedemptionExpiry).to.equal(
          timestamp + redmeptionPeriod
        );
      });

      it("should revert once the deposit amount has already been reached", async function () {
        await aelinDeal
          .connect(holder)
          .depositUnderlying(underlyingDealTokenTotal);

        await expect(
          aelinDeal.connect(holder).depositUnderlying(underlyingDealTokenTotal)
        ).to.be.revertedWith("deposit already complete");
      });

      it("should not finalize the deposit if the total amount has not been deposited", async function () {
        expect(await aelinDeal.depositComplete()).to.equal(false);
        const lowerAmount = underlyingDealTokenTotal.sub(1);
        await underlyingDealToken.mock.balanceOf
          .withArgs(holder.address)
          .returns(lowerAmount);

        await underlyingDealToken.mock.transferFrom
          .withArgs(holder.address, aelinDeal.address, lowerAmount)
          .returns(true);

        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(ethers.BigNumber.from(0));

        await aelinDeal.connect(holder).depositUnderlying(lowerAmount);

        expect(await aelinDeal.depositComplete()).to.equal(false);

        const [depositDealTokensLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.DepositDealTokens()
        );

        expect(depositDealTokensLog.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(depositDealTokensLog.args.depositor).to.equal(holder.address);
        expect(depositDealTokensLog.args.dealContract).to.equal(
          aelinDeal.address
        );
        expect(depositDealTokensLog.args.underlyingDealTokenAmount).to.equal(
          lowerAmount
        );

        const dealFullyFundedLogs = await aelinDeal.queryFilter(
          aelinDeal.filters.DealFullyFunded()
        );
        expect(dealFullyFundedLogs.length).to.equal(0);
      });
    });

    describe("mint", function () {
      it("should mint tokens", async function () {
        expect(await aelinDeal.totalSupply()).to.equal(
          ethers.BigNumber.from(0)
        );
        await aelinDeal.connect(deployer).mint(purchaser.address, mintAmount);
        expect(await aelinDeal.totalSupply()).to.equal(mintAmount);
        expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(
          mintAmount
        );
        const [mintLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.MintDealTokens()
        );
        expect(mintLog.args.dealContract).to.equal(aelinDeal.address);
        expect(mintLog.args.recipient).to.equal(purchaser.address);
        expect(mintLog.args.dealTokenAmount).to.equal(mintAmount);
      });

      it("should not allow mint tokens for the wrong account (only the deployer which is enforced as the pool)", async function () {
        await expect(
          aelinDeal.connect(holder).mint(purchaser.address, mintAmount)
        ).to.be.revertedWith("only AelinPool can access");
      });
    });

    describe("withdraw", function () {
      const excessAmount = ethers.utils.parseUnits(
        "10",
        underlyingDealTokenDecimals
      );

      it("should allow the holder to withdraw excess tokens from the pool", async function () {
        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(underlyingDealTokenTotal.add(excessAmount));

        await underlyingDealToken.mock.transfer
          .withArgs(holder.address, excessAmount)
          .returns(true);

        await aelinDeal.connect(holder).withdraw();
        const [log] = await aelinDeal.queryFilter(
          aelinDeal.filters.WithdrawUnderlyingDealTokens()
        );
        expect(log.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(log.args.depositor).to.equal(holder.address);
        expect(log.args.dealContract).to.equal(aelinDeal.address);
        expect(log.args.underlyingDealTokenAmount).to.equal(excessAmount);
      });

      it("should block anyone else from withdrawing excess tokens from the pool", async function () {
        await expect(aelinDeal.connect(deployer).withdraw()).to.be.revertedWith(
          "only holder can access"
        );
      });

      it("should block the holder from withdrawing when there are no excess tokens in the pool", async function () {
        await underlyingDealToken.mock.transfer
          .withArgs(holder.address, excessAmount)
          .returns(true);

        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(underlyingDealTokenTotal.sub(excessAmount));
        try {
          await aelinDeal.connect(holder).withdraw();
        } catch (e: any) {
          expect(e.message).to.equal(
            "VM Exception while processing transaction: reverted with panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
          );
        }
      });
    });

    describe("withdrawExpiry", function () {
      it("should allow the holder to withdraw excess tokens in the pool after expiry", async function () {
        await fundDealAndMintTokens();
        // wait for redemption period to end
        await ethers.provider.send("evm_increaseTime", [redmeptionPeriod + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(underlyingDealTokenTotal);

        await underlyingDealToken.mock.transfer
          .withArgs(holder.address, remainingBalance)
          .returns(true);

        await aelinDeal.connect(holder).withdrawExpiry();

        const [log] = await aelinDeal.queryFilter(
          aelinDeal.filters.WithdrawUnderlyingDealTokens()
        );
        expect(log.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(log.args.depositor).to.equal(holder.address);
        expect(log.args.dealContract).to.equal(aelinDeal.address);
        expect(log.args.underlyingDealTokenAmount).to.equal(remainingBalance);
      });

      it("should block the holder from withdraw excess tokens in the pool before redeem window starts", async function () {
        // the deal is not funded so the redeem window has not started yet
        await expect(
          aelinDeal.connect(holder).withdrawExpiry()
        ).to.be.revertedWith("redemption period not started");
      });

      it("should block the holder from withdraw excess tokens in the pool while redeem window is active", async function () {
        await fundDealAndMintTokens();
        // no waiting for redemption period to end
        await underlyingDealToken.mock.balanceOf
          .withArgs(aelinDeal.address)
          .returns(remainingBalance);

        await underlyingDealToken.mock.transfer
          .withArgs(holder.address, remainingBalance)
          .returns(true);
        await expect(
          aelinDeal.connect(holder).withdrawExpiry()
        ).to.be.revertedWith("redeem window still active");
      });
    });

    describe("claim and custom transfer", function () {
      it("should allow the purchaser to claim their fully vested tokens only once", async function () {
        await fundDealAndMintTokens();
        // wait for redemption period and the vesting period to end
        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transfer
          .withArgs(purchaser.address, expectedClaimUnderlying)
          .returns(true);

        await expect(
          aelinDeal.connect(deployer).claim(sponsor.address)
        ).to.be.revertedWith("nothing to claim");
        await aelinDeal.connect(purchaser).claim(purchaser.address);

        const [log] = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        expect(log.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(log.args.from).to.equal(purchaser.address);
        expect(log.args.recipient).to.equal(purchaser.address);
        expect(log.args.underlyingDealTokensClaimed).to.equal(
          expectedClaimUnderlying
        );

        expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(0);
      });

      it("should allow the purchaser to claim and allocate their fully vested tokens only once", async function () {
        await fundDealAndMintTokens();
        // wait for redemption period and the vesting period to end
        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transfer
          .withArgs(deployer.address, expectedClaimUnderlying)
          .returns(true);

        await aelinDeal.connect(purchaser).claim(deployer.address);

        const [log] = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        expect(log.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(log.args.from).to.equal(purchaser.address);
        expect(log.args.recipient).to.equal(deployer.address);
        expect(log.args.underlyingDealTokensClaimed).to.equal(
          expectedClaimUnderlying
        );

        expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(0);
      });

      it("should allow the purchaser to claim their partially vested tokens", async function () {
        // NOTE that this is deterministic and roughly half but it is hard to find
        // the exact timestamp when calling evm_increaseTime
        const partiallyExpectedClaimUnderlying = 202739814;
        await fundDealAndMintTokens();

        await ethers.provider.send("evm_increaseTime", [
          redemptionEnd - oneDay * 180,
        ]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transfer
          .withArgs(purchaser.address, partiallyExpectedClaimUnderlying)
          .returns(true);

        await aelinDeal.connect(purchaser).claim(purchaser.address);

        const [log] = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        expect(log.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(log.args.from).to.equal(purchaser.address);
        expect(log.args.recipient).to.equal(purchaser.address);
        expect(log.args.underlyingDealTokensClaimed).to.equal(
          partiallyExpectedClaimUnderlying
        );
      });

      it("should claim their minted tokens when doing a transfer", async function () {
        await fundDealAndMintTokens();
        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transfer
          .withArgs(purchaser.address, expectedClaimUnderlying)
          .returns(true);

        await aelinDeal
          .connect(purchaser)
          .transfer(deployer.address, mintAmount);

        const [claimLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        const transferLogs = await aelinDeal.queryFilter(
          aelinDeal.filters.Transfer()
        );

        expect(claimLog.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );
        expect(claimLog.args.from).to.equal(purchaser.address);
        expect(claimLog.args.recipient).to.equal(purchaser.address);
        expect(claimLog.args.underlyingDealTokensClaimed).to.equal(
          expectedClaimUnderlying
        );

        expect(transferLogs[0].args.from).to.equal(nullAddress);
        expect(transferLogs[0].args.to).to.equal(purchaser.address);
        expect(transferLogs[0].args.amount).to.equal(mintAmount);

        expect(transferLogs[1].args.from).to.equal(purchaser.address);
        expect(transferLogs[1].args.to).to.equal(nullAddress);
        // @NOTE I thought the safeTransfer might emit an event  with the expected claim amount?
        expect(transferLogs[1].args.amount).to.equal(mintAmount);

        expect(transferLogs[2].args.from).to.equal(purchaser.address);
        expect(transferLogs[2].args.to).to.equal(deployer.address);
        expect(transferLogs[2].args.amount).to.equal(mintAmount);

        expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(0);
      });

      it("should claim their minted tokens when doing a transferFrom", async function () {
        await fundDealAndMintTokens();

        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transferFrom
          .withArgs(purchaser.address, holder.address, mintAmount)
          .returns(true);

        await underlyingDealToken.mock.transfer
          .withArgs(purchaser.address, expectedClaimUnderlying)
          .returns(true);

        await aelinDeal
          .connect(purchaser)
          .approve(deployer.address, mintAmount);

        await aelinDeal
          .connect(deployer)
          .transferFrom(purchaser.address, holder.address, mintAmount);

        const [claimLog] = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        const transferLogs = await aelinDeal.queryFilter(
          aelinDeal.filters.Transfer()
        );

        expect(claimLog.args.underlyingDealTokenAddress).to.equal(
          underlyingDealToken.address
        );

        expect(claimLog.args.from).to.equal(purchaser.address);
        expect(claimLog.args.recipient).to.equal(purchaser.address);
        expect(claimLog.args.underlyingDealTokensClaimed).to.equal(
          expectedClaimUnderlying
        );

        expect(transferLogs[0].args.from).to.equal(nullAddress);
        expect(transferLogs[0].args.to).to.equal(purchaser.address);
        expect(transferLogs[0].args.amount).to.equal(mintAmount);

        expect(transferLogs[1].args.from).to.equal(purchaser.address);
        expect(transferLogs[1].args.to).to.equal(nullAddress);
        expect(transferLogs[1].args.amount).to.equal(mintAmount);

        expect(transferLogs[2].args.from).to.equal(purchaser.address);
        expect(transferLogs[2].args.to).to.equal(holder.address);
        expect(transferLogs[2].args.amount).to.equal(mintAmount);

        expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(0);
      });

      it("should not allow a random wallet with no balance to claim", async function () {
        await fundDealAndMintTokens();
        // wait for redemption period and the vesting period to end
        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        await underlyingDealToken.mock.transfer
          .withArgs(purchaser.address, expectedClaimUnderlying)
          .returns(true);

        await aelinDeal.connect(deployer).claim(deployer.address);
        const claimedLogs = await aelinDeal.queryFilter(
          aelinDeal.filters.ClaimedUnderlyingDealTokens()
        );
        expect(claimedLogs.length).to.equal(0);
      });
    });
    describe("underlyingDealTokensClaimable", function () {
      it("should return the correct amount of tokens claimable after fully vested", async function () {
        await fundDealAndMintTokens();
        // wait for redemption period and the vesting period to end
        await ethers.provider.send("evm_increaseTime", [redemptionEnd + 1]);
        await ethers.provider.send("evm_mine", []);

        const result = await aelinDeal.underlyingDealTokensClaimable(
          purchaser.address
        );
        expect(result).to.equal(expectedClaimUnderlying);
      });
      it("should return the correct amount of tokens claimable after partially vested", async function () {
        // NOTE that this is deterministic and roughly half but it is hard to find
        // the exact timestamp when calling evm_increaseTime
        const partialClaimValue = 202739789;
        await fundDealAndMintTokens();

        await ethers.provider.send("evm_increaseTime", [
          redemptionEnd - oneDay * 180,
        ]);
        await ethers.provider.send("evm_mine", []);

        const result = await aelinDeal.underlyingDealTokensClaimable(
          purchaser.address
        );
        expect(result).to.equal(partialClaimValue);
      });
      it("should return the correct amount of tokens claimable when not vested or with no balance", async function () {
        const result = await aelinDeal.underlyingDealTokensClaimable(
          deployer.address
        );
        expect(result).to.equal(0);
      });
    });
  });
  describe("custom deal initializations", function () {
    it("should allow a purchaser to claim their tokens right away if there is no vesting schedule", async function () {
      aelinDeal
        .connect(deployer)
        .initialize(
          name,
          symbol,
          underlyingDealToken.address,
          underlyingDealTokenTotal,
          0,
          0,
          proRataRedemptionPeriod,
          openRedemptionPeriod,
          holder.address,
          poolTokenMaxPurchaseAmount
        );

      await fundDealAndMintTokens();
      await ethers.provider.send("evm_increaseTime", [
        proRataRedemptionPeriod + openRedemptionPeriod + 1,
      ]);
      await ethers.provider.send("evm_mine", []);

      const result = await aelinDeal.underlyingDealTokensClaimable(
        purchaser.address
      );
      expect(result).to.equal(expectedClaimUnderlying);

      await underlyingDealToken.mock.transfer
        .withArgs(purchaser.address, expectedClaimUnderlying)
        .returns(true);

      await aelinDeal.connect(purchaser).claim(purchaser.address);

      const [log] = await aelinDeal.queryFilter(
        aelinDeal.filters.ClaimedUnderlyingDealTokens()
      );
      expect(log.args.underlyingDealTokenAddress).to.equal(
        underlyingDealToken.address
      );
      expect(log.args.from).to.equal(purchaser.address);
      expect(log.args.recipient).to.equal(purchaser.address);
      expect(log.args.underlyingDealTokensClaimed).to.equal(
        expectedClaimUnderlying
      );

      expect(await aelinDeal.balanceOf(purchaser.address)).to.equal(0);
    });
  });
});
