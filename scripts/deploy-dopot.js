/*  
npx hardhat run --network mumbai scripts/deploy-dopot.js

npx hardhat size-contracts

Utils lib deployed to: 0xB3967025E85C33a9179EeD5F3c115cEdd9667948
ProjectFactory deployed to: 0xDdF6a52E6bAe584F864198790150a9B0d4634B76
Reward deployed to: 0x92d01555b1a5a8549f5B3E5B9368419432A39DC5
$DPT deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
*/
const { ethers, upgrades } = require("hardhat");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  /*const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Dopot deployed to:", token.address);
  console.log("Dopot deployerBalance: " + deployerBalance);*/

  const Utils = await ethers.getContractFactory("Utils");
  const utils = await Utils.deploy();
  await utils.deployed();
  console.log("Utils deployed to:", utils.address);

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: utils.address }  });
  const dptUniPoolAddress = "0x0000000000000000000000000000000000000000"; // call getPool(token,token,3000) of Uni v3 factory (0x1F98431c8aD98523631AE4a59f267346ea31F984) to get this = 0x2A33D7FcdCde0D7A82b2D470d0D9eDb21400Aa11
  const dptTokenAddress = "0x0000000000000000000000000000000000000000";
  const fundingTokenContract = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1";

  const projectfactory = await ProjectFactory.deploy(fundingTokenContract, dptTokenAddress, dptUniPoolAddress);
  await projectfactory.deployed();
  console.log("ProjectFactory deployed to:", projectfactory.address);

  const Reward = await ethers.getContractFactory("DopotReward", { libraries: {  Utils: utils.address }  });
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