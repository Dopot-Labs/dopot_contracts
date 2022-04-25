// npx hardhat run --network goerli scripts/initialize-project.js

const { ethers, upgrades } = require("hardhat");


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.attach( "0xf5B0C87590D82bf40BEA9B60fBEbecBF832AEe0d" );

  const raiseBy = new Date("2022-12-31T23:59:59.000Z").getTime();
  const projectMedia = ["0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2"];
  const rewardTiers = [{ipfshash: "0x1db59a982e018221f8f97b9044f13d58b8ed5c4b7943fe48cad9ca8f68f9c23c", tokenId: 0, investment: amountTokens, supply: 100}];
  const survey = "0xedeb62f6233e9de80fb9d67cf307844046c5e62631045868adaf5e221ad9cf62";

  let projecttx = await projectfactory.connect(deployer).createProject(raiseBy, projectMedia, rewardTiers, survey);
  let receipt = await projecttx.wait(1);
  let projectCreatedEvent = receipt.events.pop();
  let projectaddr = projectCreatedEvent.args["project"];
  console.log("Project Address: " + projectaddr)
  const Project = await ethers.getContractFactory("Project");
  var project = await Project.attach(projectaddr);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});