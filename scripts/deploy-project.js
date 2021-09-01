const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.deploy("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", 12, 123, 1);
  await projectfactory.deployed();

  console.log("ProjectFactory deployed to:", project.address);
  const project1 = await projectfactory.createProject();
  const project2 = await projectfactory.createProject();

}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});