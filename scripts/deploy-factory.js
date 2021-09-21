const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.deploy("0x8A791620dd6260079BF849Dc5567aDC3F2FdC318");
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