import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers as Ethers } from "ethers";
import { ethers, network } from "hardhat";

export const fundUsers = async (
  contract: Ethers.Contract,
  signer: SignerWithAddress,
  amount: Ethers.BigNumber,
  users: SignerWithAddress[]
): Promise<void> => {
  users.forEach((user) => {
    contract.connect(signer).transfer(user.address, amount);
  });
};

export const getImpersonatedSigner = async (
  address: string
): Promise<SignerWithAddress> => {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });

  return ethers.getSigner(address);
};

export const mockAelinRewardsAddress =
  "0xfdbdb06109CD25c7F485221774f5f96148F1e235";
