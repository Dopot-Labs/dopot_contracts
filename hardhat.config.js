
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config()

const blockscanAPIkey = process.env.blockscanAPIkey;
const alchemyAPIkey = process.env.ALCHEMY_API_KEY;
const privateKey = process.env.PRIVATE_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.9",
  gasReporter: {
    currency: 'EUR',
    enabled: true,
    gasPrice: 3
  },
  optimizer: {
    enabled: true,
    runs: 1 
  },
  etherscan: {
    apiKey: blockscanAPIkey
  },
  networks: {
    goerli: {
      url: `https://rpc.goerli.mudit.blog`, // https://eth-goerli.alchemyapi.io/v2/${alchemyAPIkey}
      accounts: [`0x${privateKey}`],
      gas: 2100000
    }
  },
};
