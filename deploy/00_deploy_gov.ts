import {DeployFunction} from 'hardhat-deploy/types';
import {DeFiatGov} from '../typechain/DeFiatGov';

const func: DeployFunction = async ({getNamedAccounts, deployments, network, ethers}) => {  
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  
  if (!network.live) {
    const result = await deploy('DeFiatGov', {
      from: deployer,
      log: true
    })
  
    if (result.newlyDeployed) {
      const Governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
  
      await Governance.changeBurnRate(50).then(tx => tx.wait());
      await Governance.changeFeeRate(200).then(tx => tx.wait()); 
    }
  }
};

export default func;