import { ethers, deployments, getNamedAccounts } from 'hardhat'
import { expect } from 'chai'
import { AnyStake, AnyStakeRegulator, AnyStakeVault, DeFiatGov, DeFiatPoints, DeFiatToken } from '../typechain'
import { parseEther } from 'ethers/lib/utils';

describe('AnyStake', () => {
	beforeEach(async () => {
		await deployments.fixture();
	})

	it('should deploy and setup AnyStake correctly', async () => {
		const { deployer } = await getNamedAccounts();
		const AnyStake = await ethers.getContract('AnyStake', deployer) as AnyStake;
		const AnyStakeVault = await ethers.getContract('AnyStakeVault', deployer) as AnyStakeVault;

		const vaultAddress = await AnyStake.Vault();
		const anystakeAddress = await AnyStakeVault.AnyStake();

		expect(vaultAddress).to.equal(AnyStakeVault.address);
		expect(anystakeAddress).to.equal(AnyStake.address);
	})

	describe('deposit()', () => {
		const tests = [
			{args: ["DFT-LP", 0], expected: 0},
			{args: ["DFT-LP", 0], expected: 0},
			{args: ["DFT-LP", 0], expected: 0},
			{args: ["DFT-LP", 0], expected: 0},
			{args: ["DFT-LP", 0], expected: 0},
			{args: ["DFT-LP", 0], expected: 0},
		]

		tests.forEach(test => {
			it('should allow deposits of ' + test.args[0] + ' in PID: ' + test.args[1], async () => {

			})
		})
	})

	

	it('should allow claims of pending rewards', async () => {

	})

	it('should reject claims when no staked balance', async () => {
		const {beta} = await getNamedAccounts();
		const AnyStake = await ethers.getContract('AnyStake', beta) as AnyStake;

		// expect(AnyStake.claim()).to.be.reverted;
		// expect(AnyStake.claimAll()).to.be.reverted;
	})

	it('should allow withdraws from staking pools', async () => {

	})

	it('should reject withdraws when invalid', async () => {
		const {alpha, beta} = await getNamedAccounts();
		const AnyStakeAlpha = await ethers.getContract('AnyStake', alpha) as AnyStake;
		const AnyStakeBeta = await ethers.getContract('AnyStake', beta) as AnyStake;

		// withdraw = 0
		// withdraw > staked

		// expect(AnyStakeBeta.withdraw(0, '0')).to.be.reverted;
		// expect(AnyStakeBeta.withdraw(0, '1')).to.be.reverted;

	})
})