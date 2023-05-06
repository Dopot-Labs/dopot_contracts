/*  
npx hardhat run --network mumbai scripts/deploy-dopot.js

npx hardhat size-contracts

$DPT deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
Reward deployed to: 0x5504c91627C2F68dAFc1Ae3D66Ce2Ce88A9704a9
ProjectFactory deployed to: 0x36e176F5E3f3eD2daa3cd27BC2bE46aC8aaaDe39
Utils lib deployed to: 0xCe3B1423b4d822f8ECB0C9699e4EF4c1866B99BA
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
  const dptUniPoolAddress = "0x71577BA8D4C4401C0db7cA91C559150Deb7Eeeed";
  const dptTokenAddress = "0x3f7d34F9A35A993A0152D04122a45762fA774140";
  const fundingTokenContract = "0xaFf77C74E2a3861225173C2325314842338b73e6";

  const projectfactory = await ProjectFactory.deploy(fundingTokenContract, dptTokenAddress, dptUniPoolAddress);
  await projectfactory.deployed();
  console.log("ProjectFactory deployed to:", projectfactory.address);

  const Reward = await ethers.getContractFactory("DopotReward", { libraries: {  Utils: utils.address }  });
  const reward = await Reward.deploy(projectfactory.address);
  await reward.deployed();
  console.log("Reward deployed to:", reward.address);

  console.log("a");
  await projectfactory.setRewardContract(reward.address);
  console.log("b");
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});