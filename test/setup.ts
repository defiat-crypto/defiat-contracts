import { BigNumber, BigNumberish } from "ethers";
import { ethers, deployments, getNamedAccounts } from "hardhat";
import IERC20Abi from "../abi/IERC20.json";
import IUniswapV2PairAbi from "../abi/IUniswapV2Pair.json";
import IUniswapV2Router02Abi from "../abi/IUniswapV2Router02.json";
import IWETHAbi from "../abi/IWETH.json";
import {
  AnyStake,
  AnyStakeRegulator,
  AnyStakeVault,
  DeFiatGov,
  DeFiatPoints,
  DeFiatToken,
  IERC20,
  IUniswapV2Router02,
  IWETH,
} from "../typechain";

const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const CORE = "0x62359ed7505efc61ff1d56fef82158ccaffa23d7";

export const tokens = [
  { address: "", amount: "" },
  { address: "", amount: "" },
  { address: "", amount: "" },
  { address: "", amount: "" },
  { address: "", amount: "" },
];

export const setupTest = deployments.createFixture(async (hre, options) => {
  await deployments.fixture();

  const { deployer, alpha, beta } = await getNamedAccounts();
  const DFT = (await ethers.getContract(
    "DeFiatToken",
    deployer
  )) as DeFiatToken;
  const DFTP = (await ethers.getContract(
    "DeFiatPoints",
    deployer
  )) as DeFiatPoints;
  const Gov = (await ethers.getContract("DeFiatGov", deployer)) as DeFiatGov;
  const AnyStake = (await ethers.getContract("AnyStake", deployer)) as AnyStake;
  const Vault = (await ethers.getContract(
    "AnyStakeVault",
    deployer
  )) as AnyStakeVault;
  const Regulator = (await ethers.getContract(
    "AnyStakeRegulator",
    deployer
  )) as AnyStakeRegulator;

  await setup(deployer, alpha, DFT, DFTP);

  return {
    deployer,
    alpha,
    beta,
    DFT,
    DFTP,
    Gov,
    AnyStake,
    Vault,
    Regulator,
  };
});

const setup = async (
  deployer: string,
  alpha: string,
  DFT: DeFiatToken,
  DFTP: DeFiatPoints
) => {
  const router = await getRouter(deployer);

  // send DFT / mint DFTP to alpha
  await DFT.transfer(alpha, ethers.utils.parseEther("300000")).then((tx) =>
    tx.wait()
  );
  console.log("dft");
  await DFTP.overrideLoyaltyPoints(
    alpha,
    ethers.utils.parseEther("100000")
  ).then((tx) => tx.wait());
  console.log("dftp");

  // add liquidity to DFT/ETH
  await approveToken(DFT.address, alpha, router.address);
  await addLiquidity(DFT.address, ethers.utils.parseEther("100"), "10", alpha);
  console.log("add liq dft");

  // // add liquidity to DFTP/ETH
  await approveToken(DFT.address, alpha, router.address);
  await addLiquidity(DFT.address, ethers.utils.parseEther("100"), "10", alpha);
  console.log("add liq dftp");

  // // convert ETH to WETH
  await depositForWeth(alpha, ethers.utils.parseEther("10"));
  console.log("deposit eth for weth");

  // buy USDC and CORE test tokens
  await buyToken(USDC, ethers.utils.parseEther("10"), alpha);
  await buyToken(CORE, ethers.utils.parseEther("10"), alpha);
  console.log("buy test tokens");
};

const approveToken = async (
  address: string,
  signer: string,
  spender: string
) => {
  const Token = await getToken(address, signer);
  await Token.approve(spender, ethers.constants.MaxUint256).then((tx) =>
    tx.wait()
  );
};

const buyToken = async (
  address: string,
  value: BigNumberish,
  signer: string
): Promise<BigNumberish> => {
  const Token = await getToken(address, signer);
  const Router = await getRouter(signer);
  const WETH = await Router.WETH();

  await Router.swapExactETHForTokensSupportingFeeOnTransferTokens(
    "0",
    [WETH, address],
    signer,
    Date.now() + 30000,
    {
      value,
    }
  ).then((tx) => tx.wait());

  const balance = await Token.balanceOf(signer);
  return balance;
};

const addLiquidity = async (
  address: string,
  amount: BigNumberish,
  value: BigNumberish,
  signer: string
): Promise<BigNumberish> => {
  const Token = await getToken(address, signer);
  const Router = await getRouter(signer);

  await Router.addLiquidityETH(
    address,
    amount,
    "0",
    "0",
    signer,
    Date.now() + 30000,
    {
      value,
    }
  ).then((tx) => tx.wait());

  // const balance = await
  return 0;
};

const depositForWeth = async (signer: string, value: BigNumberish) => {
  const router = await getRouter(signer);
  const wethAddress = await router.WETH();
  const WETH = (await ethers.getContractAt(
    IWETHAbi,
    wethAddress,
    signer
  )) as IWETH;
  await WETH.deposit({ value }).then((tx) => tx.wait());
};

const getRouter = async (signer: string) => {
  return (await ethers.getContractAt(
    IUniswapV2Router02Abi,
    UNISWAP_ROUTER,
    signer
  )) as IUniswapV2Router02;
};

const getToken = async (address: string, signer: string) => {
  return (await ethers.getContractAt(IERC20Abi, address, signer)) as IERC20;
};
