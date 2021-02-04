import { DeployFunction } from "hardhat-deploy/types";
import {
  AnyStake,
  AnyStakeRegulator,
  AnyStakeVault,
  DeFiatGov,
  DeFiatPoints,
  DeFiatToken,
} from "../typechain";
import GovAbi from "../abi/DeFiatGov.json";
import PointsAbi from "../abi/DeFiatPoints.json";

const func: DeployFunction = async ({
  getNamedAccounts,
  deployments,
  ethers,
}) => {
  const { deploy } = deployments;
  const { deployer, uniswap, dft, dftp, gov } = await getNamedAccounts();
  const anystake = (await ethers.getContract("AnyStake", deployer)) as AnyStake;
  const regulator = (await ethers.getContract(
    "AnyStakeRegulator",
    deployer
  )) as AnyStakeRegulator;

  console.log(anystake.address, regulator.address);

  const result = await deploy("AnyStakeVault", {
    from: deployer,
    log: true,
    args: [uniswap, dft, dftp, anystake.address, regulator.address],
  });

  if (result.newlyDeployed) {
    let governance: DeFiatGov;
    let points: DeFiatPoints;

    governance = (await ethers.getContract("DeFiatGov", deployer)) as DeFiatGov;
    points = (await ethers.getContract(
      "DeFiatPoints",
      deployer
    )) as DeFiatPoints;

    // governance = (await ethers.getContractAt(
    //   GovAbi,
    //   gov,
    //   deployer
    // )) as DeFiatGov;
    // points = (await ethers.getContractAt(
    //   PointsAbi,
    //   dftp,
    //   deployer
    // )) as DeFiatPoints;

    const vault = (await ethers.getContract(
      "AnyStakeVault",
      deployer
    )) as AnyStakeVault;

    // set the Vault as DFT Treasury destination and governor
    await governance.setFeeDestination(vault.address).then((tx) => tx.wait());
    await governance.setActorLevel(vault.address, 2).then((tx) => tx.wait());
    console.log(
      "Vault Successfully Registered as Fee Destination and Governor"
    );

    // whitelist the Anystake contracts for 0 DFT fees
    await points.overrideDiscount(vault.address, 100).then((tx) => tx.wait());
    await points
      .overrideDiscount(anystake.address, 100)
      .then((tx) => tx.wait());
    await points
      .overrideDiscount(regulator.address, 100)
      .then((tx) => tx.wait());
    console.log("AnyStake Ecosystem now whitelisted for DFT transfers");

    // initialize the other contracts now
    await anystake.initialize(vault.address).then((tx) => tx.wait());
    console.log("AnyStake Successfully Initialized.");

    await regulator.initialize(vault.address).then((tx) => tx.wait());
    console.log("Regulator Successfully Initialized");
  }
};

export default func;
