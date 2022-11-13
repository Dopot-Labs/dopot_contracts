/*  
npx hardhat run --network mumbai scripts/deploy-dopot.js

npx hardhat size-contracts

$DPT deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
Reward deployed to: 0x9eD134742004732F0C163fAe86694da532814597
ProjectFactory deployed to: 0xB4c0E6AFE589B4865e37E02f16BD5E5BA00398f8
*/
const { ethers, upgrades } = require("hardhat");
const web3 = require("web3");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  /*
  // MOCK TOKEN TO BE REPLACED BY XDAO LP
  const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Deployer DPT balance: ", web3.utils.fromWei(deployerBalance._hex));
  console.log("Dopot deployed to:", token.address);
  */
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const dptUniPoolAddress = "0x71577BA8D4C4401C0db7cA91C559150Deb7Eeeed";
  const dptTokenAddress = "0x3f7d34F9A35A993A0152D04122a45762fA774140";
  const fundingTokenContract = "0xaFf77C74E2a3861225173C2325314842338b73e6";

  const projectfactory = await ProjectFactory.deploy(fundingTokenContract, dptTokenAddress, dptUniPoolAddress);
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