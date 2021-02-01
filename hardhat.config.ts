import "dotenv/config";
import { HardhatUserConfig, task } from "hardhat/config";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-abi-exporter";
import "hardhat-typechain";

task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: "0.6.6",
  namedAccounts: {
    deployer: 0, //"0x4F4B49E7f3661652F13A6D2C86d9Af4435414721",
    uniswap: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    dft: {
      1: "0xB6eE603933E024d8d53dDE3faa0bf98fE2a3d6f1",
      4: "0xB571d40e4A7087C1B73ce6a3f29EaDfCA022C5B2",
      31337: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
    },
    dftp: {
      1: "0x8c9d8f5CC3427F460e20F63b36992f74AA19e27d",
      4: "0x70c7d7856e1558210cfbf27b7f17853655752453",
      31337: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
    },
    gov: {
      1: "0x3Aa3303877A0D1c360a9FE2693AE9f31087A1381",
      4: "0x064fd7d9c228e8a4a2bf247b432a34d6e1cb9442",
      31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
    },
    alpha: 1,
    beta: 2,
  },
  abiExporter: {
    clear: true,
    flat: true
  },
  networks: {
    hardhat: {
      // accounts: [
      //   {
      //     privateKey: `0x${process.env.DEPLOYER_PRIVATE_KEY}`,
      //     balance: "10000000000000000000000"
      //   }
      // ],
      forking: {
        blockNumber: 11768005,
        url: process.env.ALCHEMY_MAIN_DEV_KEY || ''
      }
    },
    localhost: {
      url: 'http://localhost:8545',
    },
  }
};

export default config;