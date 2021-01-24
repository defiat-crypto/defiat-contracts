import { ethers } from 'hardhat';
import {DeployFunction} from 'hardhat-deploy/types';
import {DeFiatPoints} from '../typechain/DeFiatPoints';

const func: DeployFunction = async ({getNamedAccounts, deployments}) => {  
  const {deploy, execute} = deployments;
  const {deployer} = await getNamedAccounts();
  const governance = await deployments.get('DeFiatGov');
  
  const result = await deploy('DeFiatPoints', {
    from: deployer,
    log: true
  })

  if (result.newlyDeployed) {
    const Points = await ethers.getContract('DeFiatPoints', deployer) as DeFiatPoints;
    await Points.setGovernor(governance.address, true).then(tx => tx.wait());
  }
};

export default func;