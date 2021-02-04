import { DeployFunction } from "hardhat-deploy/types";
import { AnyStake, DeFiatGov } from "../typechain";
import Addresses from "../utils/address";

const func: DeployFunction = async ({
  getNamedAccounts,
  deployments,
  ethers,
  network,
}) => {
  const { deploy, read } = deployments;
  const { deployer, uniswap, dft, dftp, gov } = await getNamedAccounts();
  console.log(dft, dftp);

  const result = await deploy("AnyStake", {
    from: deployer,
    log: true,
    args: [uniswap, dft, dftp],
  });

  if (result.newlyDeployed) {
    let governance: DeFiatGov;
    if (!network.live) {
      governance = (await ethers.getContract(
        "DeFiatGov",
        deployer
      )) as DeFiatGov;
    } else {
      const governanceArtifact = await deployments.getArtifact("DeFiatGov");
      governance = (await ethers.getContractAt(
        governanceArtifact.abi,
        gov,
        deployer
      )) as DeFiatGov;
    }

    await governance.setActorLevel(result.address, 2).then((tx) => tx.wait());
    console.log("AnyStake Governance successfully configured.");

    // batch add the pools
    // const anystake = await ethers.getContract('AnyStake', deployer) as AnyStake;
    // const tokens = Addresses.mainnet.anystake;

    // await anystake.addPoolBatch()
  }
};

export default func;
