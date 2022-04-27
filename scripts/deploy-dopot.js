/*  
npx hardhat run --network goerli scripts/deploy-dopot.js

Dopot deployed to: 0x43844668e476bF4FbBF7b82C35eb7517044026c9
Reward deployed to: 0xAfAcde5DA0229A44357a20FaF564C22E63549A4c
ProjectFactory deployed to: 0xcC644f80D3D66F077211fbfE5Bae0AB1fC367781
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
  
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const fundingTokenContract = "0x97cb342Cf2F6EcF48c1285Fb8668f5a4237BF862";
  const projectfactory = await ProjectFactory.deploy(fundingTokenContract);
  await projectfactory.deployed();
  console.log("ProjectFactory deployed to:", projectfactory.address);
  
  const Reward = await ethers.getContractFactory("DopotReward");
  const reward = await Reward.deploy(projectfactory.address);
  await reward.deployed();
  console.log("Reward deployed to:", reward.address);

  await projectfactory.setRewardContract(reward.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});