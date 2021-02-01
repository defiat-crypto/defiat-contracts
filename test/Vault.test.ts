import {ethers, deployments, getNamedAccounts} from 'hardhat'
import {expect} from 'chai'
import {AnyStake, AnyStakeRegulator, AnyStakeVault, DeFiatGov, DeFiatPoints, DeFiatToken} from '../typechain'
import { parseEther } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

describe('Vault', () => {
  beforeEach(async () => {
    await deployments.fixture();
  })

  it('should deploy and setup Vault correctly', async () => {
    const {deployer} = await getNamedAccounts();
    const Vault = await ethers.getContract('AnyStakeVault', deployer) as AnyStakeVault;
    const AnyStake = await ethers.getContract('AnyStake', deployer) as AnyStake;
    const Regulator = await ethers.getContract('AnyStakeRegulator', deployer) as AnyStakeRegulator;

    const anystakeAddress = await Vault.AnyStake();
    const regulatorAddress = await Vault.Regulator();
    const distributionBounty = await Vault.distributionBounty();
    const distributionRate = await Vault.distributionRate();

    expect(anystakeAddress).to.equal(AnyStake.address);
    expect(regulatorAddress).to.equal(Regulator.address);
    expect(distributionBounty).to.equal(30);
    expect(distributionRate).to.equal(800);
  })

  it('should price tokens correctly', async () => {
    const {deployer} = await getNamedAccounts();
    const Vault = await ethers.getContract('AnyStakeVault', deployer) as AnyStakeVault;

    const wethPrice = await Vault.getTokenPrice("WETH", "0x");
    const dftPrice = await Vault.getTokenPrice("DFT", "DFT_LP");
    const dftLpPrice = await Vault.getTokenPrice("DFT_LP", "0x");
    const usdcPrice = await Vault.getTokenPrice("USDC", "USDC_LP");

    expect(wethPrice).to.equal(BigNumber.from(1e18));
    expect(dftPrice).to.equal(BigNumber.from(1e18));
    expect(dftLpPrice).to.equal(BigNumber.from(1e18));
    expect(usdcPrice).to.equal(BigNumber.from(1e18));
  })

  it('should distribute rewards to AnyStake and Regulator and payout bounty', async () => {
    const {alpha} = await getNamedAccounts();
    const Vault = await ethers.getContract('AnyStakeVault', alpha) as AnyStakeVault;
    const AnyStake = await ethers.getContract('AnyStake', alpha) as AnyStake;
    const Regulator = await ethers.getContract('AnyStakeRegulator', alpha) as AnyStakeRegulator;
    const DFT = await ethers.getContract('DeFiatToken', alpha) as DeFiatToken;

    // send DFT to the Vault
    await Vault.distributeRewards();

    const anystakeBalance = await DFT.balanceOf(AnyStake.address);
    const regulatorBalance = await DFT.balanceOf(Regulator.address);
    
    // expect()
  })
})