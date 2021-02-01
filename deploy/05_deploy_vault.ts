import {DeployFunction} from 'hardhat-deploy/types';
import { AnyStake, AnyStakeRegulator } from '../typechain';

const func: DeployFunction = async ({getNamedAccounts, deployments, ethers}) => {  
  const {deploy, execute} = deployments;
  const {deployer, uniswap, dft, dftp} = await getNamedAccounts();
  const anystake = await ethers.getContract('AnyStake', deployer) as AnyStake;
  const regulator = await ethers.getContract('AnyStakeRegulator', deployer) as AnyStakeRegulator;

  const result = await deploy('AnyStakeVault', {
    from: deployer,
    log: true,
    args: [uniswap, dft, dftp, anystake.address, regulator.address]
  })

  if (result.newlyDeployed) {
    await anystake.initialize(result.address).then(tx => tx.wait());
    console.log('AnyStake Successfully Initialized.');

    await regulator.initialize(result.address).then(tx => tx.wait());
    console.log('Regulator Successfully Initialized');

    // whitelist the Vault contract for DFT fees
    // set the Vault as DFT Treasury destination
  }
};

export default func;