
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");

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
  }
};
