import { ethers, deployments, getNamedAccounts } from "hardhat";
import { expect } from "chai";
import { DeFiatGov, DeFiatPoints, DeFiatToken } from "../typechain";
import { parseEther } from "ethers/lib/utils";
import { setupTest } from "./setup";

describe("DeFiat", () => {
  it("Should deploy DeFiat Governance", async () => {
    const { deployer, Gov, Vault } = await setupTest();

    const treasury = await Gov.viewFeeDestination();
    const mastermind = await Gov.mastermind();

    expect(treasury).eq(Vault.address);
    expect(mastermind).eq(deployer);
  });

  it("Should deploy DeFiat Points", async () => {
    const { deployer, DFTP, Gov, DFT } = await setupTest();

    const name = await DFTP.name();
    const symbol = await DFTP.symbol();
    const totalSupply = await DFTP.totalSupply();
    const token = await DFTP.deFiat_Token();
    const governance = await DFTP.deFiat_Gov(deployer);
    const threshold = await DFTP.txThreshold();
    const firstTranche = await DFTP._discountTranches(1);
    const lastTranche = await DFTP._discountTranches(6);

    expect(name).eq("DeFiat Points");
    expect(symbol).eq("DFTP");
    expect(totalSupply.eq(0));
    expect(token).eq(DFT.address);
    expect(governance).true;
    expect(threshold.eq(parseEther("100")));
    expect(firstTranche.eq(parseEther("100")));
    expect(lastTranche.eq(parseEther("10000")));
  });

  it("Should deploy DeFiat Token", async () => {
    const { deployer, DFT, DFTP, Gov } = await setupTest();

    const name = await DFT.name();
    const symbol = await DFT.symbol();
    const totalSupply = await DFT.totalSupply();
    const governance = await DFT.DeFiat_gov();
    const points = await DFT.DeFiat_points();
    const burnRate = await DFT._viewBurnRate();
    const feeRate = await DFT._viewFeeRate();

    expect(name).eq("DeFiat");
    expect(symbol).eq("DFT");
    expect(totalSupply.eq(parseEther("500000")));
    expect(governance).eq(Gov.address);
    expect(points).eq(DFTP.address);
    expect(burnRate.eq(50));
    expect(feeRate.eq(200));
  });
});
