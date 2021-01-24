import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-abi-exporter";
import "hardhat-typechain";

const config: HardhatUserConfig = {
  solidity: "0.6.6",
  namedAccounts: {
    deployer: 0
  },
  abiExporter: {
    clear: true,
    flat: true
  },
  networks: {
    hardhat: {
      forking: {
        blockNumber: 11705000,
        url: process.env.ALCHEMY_MAIN_DEV_KEY || ''
      }
    },
    localhost: {
      url: 'http://localhost:8545',
    },
  }
};

export default config;