
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-contract-sizer');
require('dotenv').config()

const blockscanAPIkey = process.env.blockscanAPIkey;
const arbiscanAPIkey = process.env.arbiscanAPIkey;
const alchemyAPIkey = process.env.ALCHEMY_API_KEY;
const privateKey = process.env.PRIVATE_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000
      }
    }
  },
  gasReporter: {
    currency: 'EUR',
    L2: "arbitrum",
    L2Etherscan: arbiscanAPIkey,
    enabled: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,

    reportFormat: "markdown",
    forceTerminalOutput: true,
    forceTerminalOutputFormat: "terminal",
  },
  etherscan: {
    apiKey: arbiscanAPIkey
  },
  networks: {
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.RINKEBY_ALCHEMY_API_KEY}`,
      accounts: [`0x${privateKey}`],
      gas: 30000000
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${process.env.GOERLI_ALCHEMY_API_KEY}`,
      accounts: [`0x${privateKey}`],
      gas: 30000000 
    },
    kovan: {
      url: `https://kovan.poa.network`, // https://eth-goerli.alchemyapi.io/v2/${alchemyAPIkey}
      accounts: [`0x${privateKey}`],
      gas: 2100000
    },
    sepolia: {
      url: `https://rpc.sepolia.dev`, // https://eth-goerli.alchemyapi.io/v2/${alchemyAPIkey}
      accounts: [`0x${privateKey}`],
      gas: 2100000
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.MUMBAI_ALCHEMY_API_KEY}`,
      accounts:   [`0x${privateKey}`],
      gas: 6000000
    },
    arbitrum: {
      url: `https://arbitrum.llamarpc.com`,
      accounts:   [`0x${privateKey}`]
    }
  },
  sourcify: {
    enabled: true
  }
};
