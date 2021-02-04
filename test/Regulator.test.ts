import { ethers, deployments, getNamedAccounts } from "hardhat";
import { expect } from "chai";
import {
  AnyStake,
  AnyStakeRegulator,
  AnyStakeVault,
  DeFiatGov,
  DeFiatPoints,
  DeFiatToken,
} from "../typechain";
import { parseEther } from "ethers/lib/utils";
import { setupTest } from "./setup";

describe("Regulator", () => {
  it("should deploy and setup Regulator correctly", async () => {
    const { deployer, Regulator, Vault } = await setupTest();

    const vaultAddress = await Regulator.Vault();
    const regulatorAddress = await Vault.Regulator();

    expect(vaultAddress).to.equal(Vault.address);
    expect(regulatorAddress).to.equal(Regulator.address);
  });

  it("should accept deposits and burn from Uniswap", async () => {
    const { alpha, Regulator } = await setupTest();

    // simulate when DFTP price is below the peg
  });

  it("should accept deposits and buy on Uniswap", async () => {
    const { alpha, Regulator } = await setupTest();

    // simulate when DFTP price is above the peg
  });

  it("should claim rewards and reset stake", async () => {
    const { alpha, DFT, Regulator } = await setupTest();

    await Regulator.claim();

    const balance = await DFT.balanceOf(alpha);
    const stake = await Regulator.userInfo(alpha);

    expect(balance.gt(0));
    expect(stake.amount.eq(0));
  });

  it("should reject claims when no staked balance", async () => {
    const { beta, Regulator } = await setupTest();

    // expect(AnyStakeRegulator.claim()).to.be.reverted;
  });
});
