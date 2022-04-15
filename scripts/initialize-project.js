// npx hardhat run --network goerli scripts/initialize-project.js

const { ethers, upgrades } = require("hardhat");


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.attach( "0xf5B0C87590D82bf40BEA9B60fBEbecBF832AEe0d" );

  const raiseBy = new Date("2022-12-31T23:59:59.000Z").getTime();
  const projectMedia = [{digest: "0xe5973e06eb2d89cdad75dd631e33ba9d1e5bfd72cc75a41db565a374e451daf8", hashFunction: 18, size: 32}];
  const rewardTiers = [{digest: "0x499d3d9a3764e8cf679c592d71b3c8c3f4a4d4a38dd96d68f7f2757c34dd4804", hashFunction: 18, size: 32, investment: 10, supply: 100}];
  const survey = {digest: "0x6eda598f37c80b9d4bbdcc37e05eb3b23023434e5d8d7d4dbb199dd2a1240414", hashFunction: 18, size: 32};

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