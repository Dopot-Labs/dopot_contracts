/*  
npx hardhat run --network goerli scripts/deploy-dopot.js

Dopot deployed to: 0xB4c0E6AFE589B4865e37E02f16BD5E5BA00398f8
Reward deployed to: 0x1F51353D5F1D0a12913602a4061b813992D38e6F
ProjectFactory deployed to: 0x5D39EE462783cb5ffCC93daE9DB2b5F6B6194dF1
*/
const { ethers, upgrades } = require("hardhat");
const web3 = require("web3");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Deployer DPT balance: ", web3.utils.fromWei(deployerBalance._hex));
  console.log("Dopot deployed to:", token.address);

  const Reward = await ethers.getContractFactory("DopotReward");
  const reward = await Reward.deploy();
  await reward.deployed();
  console.log("Reward deployed to:", reward.address);

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const fundingTokenContract = "0x97cb342Cf2F6EcF48c1285Fb8668f5a4237BF862";
  const projectfactory = await ProjectFactory.deploy(fundingTokenContract, reward.address);
  await projectfactory.deployed();
  console.log("ProjectFactory deployed to:", projectfactory.address);
  //project1.callStatic.functionName()
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});