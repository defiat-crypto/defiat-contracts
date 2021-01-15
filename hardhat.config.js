require('dotenv').config()

require('hardhat-deploy')
require('hardhat-deploy-ethers')
require('hardhat-abi-exporter')

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.6",
  namedAccounts: {
    deployer: 0,

  },
  networks: {
    hardhat: {
      // forking: {

      // }
    },
    // rinkeby: {
    //   chainId: 4,
    //   url: "process.env.RINKEBY_ALCHEMY_KEY",
    //   accounts: ["0xPRIVATE_KEY_RINKEBY_DEPLOYER"],
    // },
    // mainnet: {
    //   chainId: 1,
    //   gasPrice: 120000000000,
    //   url: "process.env.MAINNET_ALCHEMY_KEY",
    //   accounts: ["0xPRIVATE_KEY_MAINNET_DEPLOYER"],
    // }
  }
};
