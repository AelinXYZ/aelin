import chai, { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import ERC20Artifact from "../../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import { ERC20 } from "../../typechain";

describe("integration test", () => {
  let deployer: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;
  let user5: SignerWithAddress;

  const usdcContractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  let usdcContract: ERC20;

  const usdcWhaleAddress = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let usdcWhaleSigner: SignerWithAddress;

  const uniswapWhaleAddress = "0x47173b170c64d16393a52e6c480b3ad8c302ba1e";
  let uniswapWhaleSigner: SignerWithAddress;

  const fundUsdcToUsers = async (users: SignerWithAddress[]) => {
    const amount = ethers.utils.parseUnits("50000000", 6);

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

    await fundUsdcToUsers([user1, user2, user3, user4, user5]);
  });

  it("check user balances", async () => {
    const balance = await usdcContract.balanceOf(user1.address);
    console.log("user1 balance = ", ethers.utils.formatUnits(balance, 6));
  });
});
