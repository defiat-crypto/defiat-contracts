import { ethers } from 'hardhat';
import {DeployFunction} from 'hardhat-deploy/types';
import { AnyStake, DeFiatPoints } from '../typechain';

const func: DeployFunction = async ({getNamedAccounts, deployments}) => {  
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const anystake = await ethers.getContract('AnyStake', deployer) as AnyStake;

  const result = await deploy('AnyStakeVault', {
    from: deployer,
    log: true,
    args: [anystake.address]
  })

  if (result.newlyDeployed) {
    // await anystake.initialize(result.address).then(tx => tx.wait());

    // console.log('AnyStake Successfully Initialized.')
  }
};

export default func;