
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config()

const etherscanAPIkey = process.env.polygonscanAPIkey;
const alchemyAPIkey = process.env.ALCHEMY_API_KEY;
const mumbaiPrivatekey = process.env.MUMBAI_PRIVATE_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.2",
  gasReporter: {
    currency: 'EUR',
    enabled: true,
    gasPrice: 274
  },
  optimizer: {
    enabled: true,
    runs: 1 
  },
  etherscan: {
    apiKey: etherscanAPIkey  
  },
  networks: {
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${alchemyAPIkey}`, //`https://speedy-nodes-nyc.moralis.io//polygon/mumbai`
      accounts: [`0x${mumbaiPrivatekey}`],
    }
  },
};
