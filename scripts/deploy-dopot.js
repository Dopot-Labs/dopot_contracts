/*  
npx hardhat run --network goerli scripts/deploy-dopot.js

npx hardhat size-contracts

$DPT deployed to: 0x36c42CA9cb9d42d124368eCd60B0cBBA3ACbd2E9
Reward deployed to: 0x6DFb21eEe069DBAf159Dd9294aBBCE64E625F8A6
ProjectFactory deployed to: 0xC971Aee5F6FE7BBa6e117f237f2d93b7E1E4Fc35
*/
const { ethers, upgrades } = require("hardhat");
const web3 = require("web3");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  /*
  const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Deployer DPT balance: ", web3.utils.fromWei(deployerBalance._hex));
  console.log("Dopot deployed to:", token.address);
  */
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const dptUniPoolAddress = "0xFE5496c407a892d150e4EA749d38c14E36da8ef1";
  const dptTokenAddress = "0xa1f40706958f246eda3f90c0070d1dd234e2f4a2";
  const fundingTokenContract = "0xdc31ee1784292379fbb2964b3b9c4124d8f89c60";

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