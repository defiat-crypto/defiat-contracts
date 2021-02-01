import {ethers, deployments, getNamedAccounts} from 'hardhat'
import {expect} from 'chai'
import {AnyStake, AnyStakeRegulator, AnyStakeVault, DeFiatGov, DeFiatPoints, DeFiatToken} from '../typechain'
import { parseEther } from 'ethers/lib/utils';

describe('Regulator', () => {
  beforeEach(async () => {
    await deployments.fixture();
  })

  it('should deploy and setup Regulator correctly', async () => {
    const {deployer} = await getNamedAccounts();
    const AnyStakeRegulator = await ethers.getContract('AnyStakeRegulator', deployer) as AnyStakeRegulator;
    const AnyStakeVault = await ethers.getContract('AnyStakeVault', deployer) as AnyStakeVault;

    const vaultAddress = await AnyStakeRegulator.Vault();
		const regulatorAddress = await AnyStakeVault.Regulator();

		expect(vaultAddress).to.equal(AnyStakeVault.address);
		expect(regulatorAddress).to.equal(AnyStakeRegulator.address);
  })

  it('should accept deposits and burn from Uniswap', async () => {
    const {alpha} = await getNamedAccounts();
    const AnyStakeRegulator = await ethers.getContract('AnyStakeRegulator', alpha) as AnyStakeRegulator;

    // simulate when DFTP price is below the peg


  })

  it('should accept deposits and buy on Uniswap', async () => {
    const {alpha} = await getNamedAccounts();
    const AnyStakeRegulator = await ethers.getContract('AnyStakeRegulator', alpha) as AnyStakeRegulator;

    // simulate when DFTP price is above the peg
  })

  it('should claim rewards and reset stake', async () => {
    const {alpha} = await getNamedAccounts();
    const AnyStakeRegulator = await ethers.getContract('AnyStakeRegulator', alpha) as AnyStakeRegulator;
    const DFT = await ethers.getContract('DeFiatToken', alpha) as DeFiatToken;

    await AnyStakeRegulator.claim();

    const balance = await DFT.balanceOf(alpha);
    const stake = await AnyStakeRegulator.userInfo(alpha);

    expect(balance).gt(0);
    expect(stake).equals(0);
  })

  it('should reject claims when no staked balance', async () => {
    const {beta} = await getNamedAccounts();
    const AnyStakeRegulator = await ethers.getContract('AnyStakeRegulator', beta) as AnyStakeRegulator;

    // expect(AnyStakeRegulator.claim()).to.be.reverted;
  })
})