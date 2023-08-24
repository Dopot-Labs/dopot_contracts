/* 
npx hardhat run --network mumbai scripts/initialize-project.js
*/
const { ethers, upgrades } = require("hardhat");


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: "0x80B2caa4ce38065dEcc0D74dd188d63A3c7D2139" }  });
  const projectfactory = await ProjectFactory.attach( "0x12aa172b8Df0b3f9136786c8D5a776D86cc3f6Af" );
 /*
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
  try{                        
  const projectaddr = "0xbD0f7f1db660FfDe71e408C8b9Cfb4eb35C83c16";
  const Project = await ethers.getContractFactory("Project", { libraries: {  Utils: "0x135183c1C42A8dce9F07ECd3Bbb9d2503cb18098" } });
  const project = await Project.attach(projectaddr); //projectaddr
  //const res = await project.connect(deployer).addRewardTier("bafkreihkplf2i3crflruenv4e5rnoqy6s7mrmddf7xcvzfsb7iihsgnjre", investment, amountTokens);
  const res = await project.connect(deployer).changeState(2);
  } catch (e) {
    console.log(e);
  }
  //console.log(parseInt((await project.totalGoal())._hex, 16));
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});