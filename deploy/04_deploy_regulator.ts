import {DeployFunction} from 'hardhat-deploy/types';
import {DeFiatGov} from '../typechain';

const func: DeployFunction = async ({getNamedAccounts, deployments, ethers, network}) => {  
  const {deploy} = deployments;
  const {deployer, uniswap, dft, dftp, gov} = await getNamedAccounts();

  const result = await deploy('AnyStakeRegulator', {
    from: deployer,
    log: true,
    args: [uniswap, dft, dftp]
  })

  if (result.newlyDeployed) {
    let governance: DeFiatGov;
    if (!network.live) {
      governance = await ethers.getContract('DeFiatGov', deployer) as DeFiatGov;
    } else {
      const governanceArtifact = await deployments.getArtifact('DeFiatGov');
      governance = await ethers.getContractAt(governanceArtifact.abi, gov, deployer) as DeFiatGov;
    }

    await governance.setActorLevel(result.address, 2).then(tx => tx.wait());
    console.log('Regulator Governance successfully configured.');

    // whitelist the Regulator contract for DFT fees
  }
};

export default func;