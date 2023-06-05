/* 
npx hardhat run --network mumbai scripts/initialize-project.js
*/
const { ethers, upgrades } = require("hardhat");


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
/*
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: "0xCe3B1423b4d822f8ECB0C9699e4EF4c1866B99BA" }  });
  const projectfactory = await ProjectFactory.attach( "0x36e176F5E3f3eD2daa3cd27BC2bE46aC8aaaDe39" );
 
  const fundRaisingDeadline = 45 * 60 * 60 * 24;
  const investment = 2;
  const amountTokens = 100;
  const projectMedia = "bafybeiblt47ot4baj4vl5faecqyzzmnqg3evdb7jrhiyp5adgei2ft4onm/proj.json";
  //console.dir(await projectfactory.projectsVersions(2));
 
  let projecttx = await projectfactory.connect(deployer).createProject(fundRaisingDeadline, projectMedia);
  let receipt = await projecttx.wait(1);
  let projectCreatedEvent = receipt.events.pop();
  let projectaddr = projectCreatedEvent.args["project"];
  console.log("Project Address: " + projectaddr);      */                           
  const projectaddr = "0x5157D5BFf37AeeB9A71d62F5BEcCABdEa1447c4e";
  const Project = await ethers.getContractFactory("Project", { libraries: {  Utils: "0x79423E4b6C6f4D99CBBE625F25E74df1886889e0" } });
  const project = await Project.attach(projectaddr); //projectaddr
  //const res = await project.connect(deployer).addRewardTier("bafkreihkplf2i3crflruenv4e5rnoqy6s7mrmddf7xcvzfsb7iihsgnjre", investment, amountTokens);
  const res = await project.connect(deployer).changeState(2, 0);
  //console.log(parseInt((await project.totalGoal())._hex, 16));
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});