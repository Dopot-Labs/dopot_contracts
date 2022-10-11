
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-contract-sizer');
require('dotenv').config()

const blockscanAPIkey = process.env.blockscanAPIkey;
const alchemyAPIkey = process.env.ALCHEMY_API_KEY;
const privateKey = process.env.PRIVATE_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.12",
  gasReporter: {
    currency: 'EUR',
    enabled: true,
    gasPrice: 3
  },
  optimizer: {
    enabled: true,
    runs: 1//10000
  },
  etherscan: {
    apiKey: blockscanAPIkey
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
      gas: 2100000
    },
    kovan: {
      url: `https://kovan.poa.network`, // https://eth-goerli.alchemyapi.io/v2/${alchemyAPIkey}
      accounts: [`0x${privateKey}`],
      gas: 2100000
    }
  },
};
