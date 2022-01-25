import chai, { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import AelinTokenArtifact from "../../artifacts/contracts/AelinToken.sol/AelinToken.json";
import VirtualAelinTokenArtifact from "../../artifacts/contracts/VirtualAelinToken.sol/VirtualAelinToken.json";
import VAelinConverterArtifact from "../../artifacts/contracts/VAelinConverter.sol/VAelinConverter.json";
import {
  VAelinConverter,
  AelinToken,
  VirtualAelinToken,
} from "../../typechain";

const { deployContract } = waffle;

chai.use(solidity);

describe("vAelinConverter", function () {
  let deployer: SignerWithAddress;
  let holder: SignerWithAddress;
  let beneficiary: SignerWithAddress;
  let aelinToken: AelinToken;
  let vAelinToken: VirtualAelinToken;
  let vAelinConverter: VAelinConverter;
  const decimals = 18;
  const aelinTotal = ethers.utils.parseUnits("750", decimals);
  const vAelinTotal = ethers.utils.parseUnits(
    "765.306122448979591836",
    decimals
  );
  const vAelinAmount = ethers.utils.parseUnits("10", decimals);
  const aelinAmount = ethers.utils.parseUnits("9.8", decimals);

  before(async () => {
    [deployer, holder, beneficiary] = await ethers.getSigners();
    aelinToken = (await deployContract(deployer, AelinTokenArtifact, [
      deployer.address,
    ])) as AelinToken;
    vAelinToken = (await deployContract(deployer, VirtualAelinTokenArtifact, [
      holder.address,
    ])) as VirtualAelinToken;
    vAelinConverter = (await deployContract(deployer, VAelinConverterArtifact, [
      deployer.address,
      vAelinToken.address,
      aelinToken.address,
    ])) as VAelinConverter;
    await aelinToken
      .connect(deployer)
      .transfer(vAelinConverter.address, aelinTotal);
  });

  describe("conversion", function () {
    it("should handle the conversion properly", async function () {
      expect(await aelinToken.balanceOf(holder.address)).to.equal(0);
      expect(await vAelinToken.balanceOf(holder.address)).to.equal(vAelinTotal);
      await vAelinToken
        .connect(holder)
        .approve(vAelinConverter.address, vAelinAmount);
      await vAelinConverter.connect(holder).convert(vAelinAmount);
      expect(await vAelinToken.balanceOf(holder.address)).to.equal(
        vAelinTotal.sub(vAelinAmount)
      );
      expect(await aelinToken.balanceOf(holder.address)).to.equal(aelinAmount);
      const logs = await vAelinConverter.queryFilter(
        vAelinConverter.filters.Converted()
      );
      expect(holder.address).to.equal(logs[0].args.sender);
      expect(aelinAmount).to.equal(logs[0].args.aelinReceived);
    });
    it("should have the owner as the deployer", async function () {
      expect(await vAelinConverter.owner()).to.equal(deployer.address);
    });
    it("should be able to transfer ownership", async function () {
      expect(await vAelinConverter.owner()).to.equal(deployer.address);
      await vAelinConverter.connect(deployer).nominateNewOwner(holder.address);
      expect(await vAelinConverter.owner()).to.equal(deployer.address);
      await vAelinConverter.connect(holder).acceptOwnership();
      expect(await vAelinConverter.owner()).to.equal(holder.address);
    });
    it("should self destruct properly", async function () {
      const oneYear = 365 * 24 * 60 * 60; // one year
      expect(await aelinToken.balanceOf(beneficiary.address)).to.equal(0);
      expect(await vAelinConverter.owner()).to.equal(holder.address);
      await expect(
        vAelinConverter.connect(deployer)._selfDestruct(beneficiary.address)
      ).to.be.revertedWith("Only the contract owner may perform this action");
      await expect(
        vAelinConverter.connect(holder)._selfDestruct(beneficiary.address)
      ).to.be.revertedWith("Contract can only be selfdestruct after a year");
      await ethers.provider.send("evm_increaseTime", [oneYear + 1]);
      await ethers.provider.send("evm_mine", []);
      await vAelinConverter.connect(holder)._selfDestruct(beneficiary.address);
      expect(await aelinToken.balanceOf(beneficiary.address)).to.equal(
        aelinTotal.sub(aelinAmount)
      );
    });
  });
});
