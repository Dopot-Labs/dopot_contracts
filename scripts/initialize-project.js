const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.attach( "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e" );

  const raiseBy = new Date("2021-12-31T23:59:59.000Z").getTime();
  const fundingGoal = 10;
  const minInvestment = 1;
  const project = await projectfactory.createProject(raiseBy, fundingGoal, minInvestment);
  //project1.callStatic.functionName()
  console.dir(project);
  console.log("ProjectFactory deployed to:", project.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});