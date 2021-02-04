import { DeployFunction } from "hardhat-deploy/types";
import { DeFiatPoints } from "../typechain/DeFiatPoints";

const func: DeployFunction = async ({
  getNamedAccounts,
  deployments,
  ethers,
  network,
}) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (!network.live) {
    const governance = await deployments.get("DeFiatGov");

    const result = await deploy("DeFiatPoints", {
      from: deployer,
      log: true,
    });

    if (result.newlyDeployed) {
      const Points = (await ethers.getContract(
        "DeFiatPoints",
        deployer
      )) as DeFiatPoints;
      await Points.setGovernor(governance.address, true).then((tx) =>
        tx.wait()
      );
      console.log("Governance Setup correctly");

      await Points.setTxTreshold(ethers.utils.parseEther("100")).then((tx) =>
        tx.wait()
      );

      // await Points.setAll10DiscountTranches().then(tx => tx.wait());
    }
  }
};

export default func;
