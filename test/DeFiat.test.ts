import {ethers, deployments, getNamedAccounts} from 'hardhat'
import {expect} from 'chai'
import {DeFiatGov, DeFiatPoints, DeFiatToken} from '../typechain'
import { BigNumber } from 'ethers';
import { parseEther } from 'ethers/lib/utils';

describe("DeFiat", () => {
  beforeEach(async () => {
    await deployments.fixture();
  })

  it("Should deploy DeFiat Governance", async () => {
    const {deployer} = await getNamedAccounts();
    const Governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
    
    const treasury = await Governance.viewFeeDestination();
    const mastermind = await Governance.mastermind();

    expect(treasury).eq(deployer);
    expect(mastermind).eq(deployer);
  });

  it("Should deploy DeFiat Points", async () => {
    const {deployer} = await getNamedAccounts();
    const Governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
    const Points = await ethers.getContract('DeFiatPoints', deployer) as DeFiatPoints;
    
    const name = await Points.name();
    const symbol = await Points.symbol();
    const totalSupply = await Points.totalSupply();
    const governance = await Points.deFiat_Gov(Governance.address);
    const threshold = await Points.txThreshold();
    const firstTranche = await Points._discountTranches(1);
    const lastTranche = await Points._discountTranches(6);

    expect(name).eq('DeFiat Points');
    expect(symbol).eq('DFTP');
    expect(totalSupply.eq(0));
    expect(governance).true;
    expect(threshold.eq(parseEther('100')));
    expect(firstTranche.eq(parseEther('100')));
    expect(lastTranche.eq(parseEther('10000')));
  });

  it("Should deploy DeFiat Token", async () => {
    const {deployer} = await getNamedAccounts();
    const Governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
    const Points = await ethers.getContract('DeFiatPoints', deployer) as DeFiatPoints;
    const Token = await ethers.getContract('DeFiatToken', deployer) as DeFiatToken;

    const name = await Token.name();
    const symbol = await Token.symbol();
    const totalSupply = await Token.totalSupply();
    const governance = await Token.DeFiat_gov();
    const points = await Token.DeFiat_points();
    const burnRate = await Token._viewBurnRate();
    const feeRate = await Token._viewFeeRate();

    expect(name).eq('DeFiat');
    expect(symbol).eq('DFT');
    expect(totalSupply.eq(parseEther('500000')));
    expect(governance).eq(Governance.address);
    expect(points).eq(Points.address);
    expect(burnRate.eq(50));
    expect(feeRate.eq(200));
  });
});