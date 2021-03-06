/*  
npx hardhat run --network rinkeby scripts/deploy-dopot.js

npx hardhat size-contracts

Dopot deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
Reward deployed to: 0x72D0D2f44BB102c00f934D6F6AdCeA4Ac952BDd5
ProjectFactory deployed to: 0xc158c50363d3Cc4bDc4D6C092a696194A5240eb2
*/
const { ethers, upgrades } = require("hardhat");
const web3 = require("web3");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  /*const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Deployer DPT balance: ", web3.utils.fromWei(deployerBalance._hex));
  console.log("Dopot deployed to:", token.address);*/

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const fundingTokenContract = "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735";
  const dptUniPoolAddress = "0x52e7108AFbA19103F0B0149a890aC0545E46Bb6F";
  const dptTokenAddress = "0x19d29A99880560832d9fa9B7d30211E5936B3Db7";
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