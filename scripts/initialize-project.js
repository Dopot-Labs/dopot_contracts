/* 
npx hardhat run --network rinkeby scripts/initialize-project.js
*/
const { ethers, upgrades } = require("hardhat");


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing project with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory");
  const projectfactory = await ProjectFactory.attach( "0x8689C8540385e462E402fCA15B70A6Ff6675Af13" );
  /*
  const raiseBy = new Date("2022-12-31T23:59:59.000Z").getTime();
  const investment = 2;
  const amountTokens = 100;
  const projectMedia = "0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2";
  const rewardTiers = [{ipfshash: "bafkreihkplf2i3crflruenv4e5rnoqy6s7mrmddf7xcvzfsb7iihsgnjre", tokenId: 0, investment, supply: amountTokens, projectaddress: ethers.constants.AddressZero}];
  const survey = "0xedeb62f6233e9de80fb9d67cf307844046c5e62631045868adaf5e221ad9cf62";

  let projecttx = await projectfactory.connect(deployer).createProject(raiseBy, projectMedia, rewardTiers, survey);
  let receipt = await projecttx.wait(1);
  let projectCreatedEvent = receipt.events.pop();
  let projectaddr = projectCreatedEvent.args["project"];
  console.log("Project Address: " + projectaddr)*/
  const Project = await ethers.getContractFactory("Project");
  var project = await Project.attach("0x369Aed81FEDe053f9334cbF97c4c38197224a2e0");//projectaddr
  const res = await project.prova();
  console.log(res);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});