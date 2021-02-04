import { DeployFunction } from "hardhat-deploy/types";
import { DeFiatGov, DeFiatPoints, DeFiatToken } from "../typechain";

const func: DeployFunction = async ({
  getNamedAccounts,
  deployments,
  ethers,
  network,
}) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (!network.live) {
    const Governance = (await ethers.getContract(
      "DeFiatGov",
      deployer
    )) as DeFiatGov;
    const Points = (await ethers.getContract(
      "DeFiatPoints",
      deployer
    )) as DeFiatPoints;
    console.log(Governance.address, Points.address);

    const result = await deploy("DeFiatToken", {
      from: deployer,
      log: true,
      args: [Governance.address, Points.address],
    });

    if (result.newlyDeployed) {
      // do any initial setup
      await Points.setDeFiatToken(result.address).then((tx) => tx.wait());
    }
  }
};

export default func;
