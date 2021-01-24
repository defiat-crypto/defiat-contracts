import { ethers } from 'hardhat';
import {DeployFunction} from 'hardhat-deploy/types';
import { DeFiatGov, DeFiatPoints } from '../typechain';

const func: DeployFunction = async ({getNamedAccounts, deployments}) => {  
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const Governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
  const Points = await ethers.getContract('DeFiatPoints', deployer) as DeFiatPoints;

  const result = await deploy('DeFiatToken', {
    from: deployer,
    log: true,
    args: [Governance.address, Points.address]
  })

  if (result.newlyDeployed) {
    // do any initial setup
  }
};

export default func;