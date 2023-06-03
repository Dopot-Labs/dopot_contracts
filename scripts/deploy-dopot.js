/*  
npx hardhat run --network mumbai scripts/deploy-dopot.js

npx hardhat size-contracts

Utils lib deployed to: 0x669f05FeAEdb3AF8fC87d9B1Ea2528169154413c
ProjectFactory deployed to: 0x30e573e2ABD79dB405578f787bD9b26F6bF0C1b0
Reward deployed to: 0x06a79B8C0b43608e8C77C3969eEfF07cbBD11C36
$DPT deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
*/
const { ethers, upgrades } = require("hardhat");
 
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
  console.log("Dopot deployed to:", token.address);
  */
  const Utils = await ethers.getContractFactory("Utils");
  const utils = await Utils.deploy();
  await utils.deployed();
  console.log("Utils deployed to:", utils.address);

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: utils.address }  });
  const dptUniPoolAddress = "0x0172fd18154e334b88922a09e1c498ae2a4b45cf";
  const dptTokenAddress = "0x3f7d34F9A35A993A0152D04122a45762fA774140";
  const fundingTokenContract = "0xdf5e77cB650DA50c0fe5C8A162DfD4F36C1B5Ec2";

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