import { ethers } from "hardhat";

export function stringToBytes32(s: string | string[]): string | string[] {
  if (!Array.isArray(s) && typeof s !== "string") {
    throw TypeError("Parameter must be a string or an array of strings");
  }

  if (Array.isArray(s)) {
    return s.map((s) => stringToBytes32(s) as string);
  }

  return ethers.utils.formatBytes32String(s);
}
